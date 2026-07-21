import 'dart:async';
import 'dart:convert';

import 'package:instant_share/infrastructure/websocket/ws_constants.dart';
import 'package:instant_share/infrastructure/websocket/ws_exception.dart';
import 'package:instant_share/infrastructure/websocket/ws_frame.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 连接状态。
enum WsClientState { disconnected, connected, authenticated }

/// 客户端配置。
class WsClientConfig {
  const WsClientConfig({
    this.connectTimeout = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 30),
    this.heartbeatInterval = const Duration(seconds: 15),
    this.heartbeatTimeout = const Duration(seconds: 5),
    this.heartbeatMaxFailures = 2,
  });

  /// 连接超时。
  final Duration connectTimeout;

  /// 请求超时。
  final Duration requestTimeout;

  /// 心跳间隔。
  final Duration heartbeatInterval;

  /// 单次心跳超时。
  final Duration heartbeatTimeout;

  /// 连续心跳失败次数后判定死连接。
  final int heartbeatMaxFailures;
}

/// 通用 WebSocket 客户端：连接、鉴权、request/response、二进制推送。
class WsClient {
  WsClient({this.config = const WsClientConfig()});

  /// 配置。
  final WsClientConfig config;
  static const _uuid = Uuid();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _pending = <String, Completer<WsResponse>>{};
  final _incomingController = StreamController<WsIncomingMessage>.broadcast();
  final _disconnectedController = StreamController<void>.broadcast();

  Completer<WsResponse>? _authCompleter;
  WsClientState _state = WsClientState.disconnected;

  /// 主动关闭时置位，避免误触发 [disconnected]。
  bool _closingIntentionally = false;

  /// 防止 _onError/_onDone 重复广播断线。
  bool _disconnectEmitted = false;

  Timer? _heartbeatTimer;
  int _heartbeatFailures = 0;
  bool _heartbeatInFlight = false;

  /// 连接状态。
  WsClientState get state => _state;

  /// 入站消息流。
  Stream<WsIncomingMessage> get incoming => _incomingController.stream;

  /// 非主动关闭导致的断线事件（半开探测失败、对端关闭、网络错误等）。
  Stream<void> get disconnected => _disconnectedController.stream;

  /// 是否已认证。
  bool get isAuthenticated => _state == WsClientState.authenticated;

  /// 建立 WebSocket 连接（尚未鉴权）。
  Future<void> connect(Uri uri) async {
    await close(intentional: true);
    _closingIntentionally = false;
    _disconnectEmitted = false;
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _state = WsClientState.connected;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  /// 发送 auth 首帧并等待 `auth_ack`。
  Future<WsResponse> authenticate(WsAuthRequest auth) async {
    _ensureConnected();
    if (_authCompleter != null) {
      throw const WsException(message: 'auth already in progress');
    }

    _authCompleter = Completer<WsResponse>();
    _sink.add(jsonEncode(auth.toJson()));

    try {
      final response = await _authCompleter!.future.timeout(
        config.connectTimeout,
        onTimeout: () => throw WsException(
          message: 'auth timeout',
          frameType: WsFrameType.authAck,
        ),
      );
      response.ensureSuccess();
      _state = WsClientState.authenticated;
      return response;
    } finally {
      _authCompleter = null;
    }
  }

  /// 发送业务帧并等待同 `request_id` 的 JSON 响应。
  Future<WsResponse> request(
    String type, {
    Object? data,
    String? requestId,
    Duration? timeout,
  }) async {
    _ensureAuthenticated();

    final id = requestId ?? _uuid.v4();
    final completer = Completer<WsResponse>();
    _pending[id] = completer;

    _sink.add(
      jsonEncode(WsPacket(type: type, requestId: id, data: data).toJson()),
    );

    try {
      return await completer.future.timeout(
        timeout ?? config.requestTimeout,
        onTimeout: () => throw WsException(
          message: 'request timeout',
          frameType: type,
          requestId: id,
        ),
      );
    } finally {
      _pending.remove(id);
    }
  }

  /// 发送业务心跳并等待 `pong`。
  Future<void> ping({Duration? timeout}) async {
    final response = await request(
      WsFrameType.ping,
      timeout: timeout ?? config.heartbeatTimeout,
    );
    if (response.type != WsFrameType.pong) {
      throw WsException(
        message: 'unexpected ping response: ${response.type}',
        code: response.code,
        frameType: response.type,
        requestId: response.requestId,
      );
    }
    response.ensureSuccess();
  }

  /// 启动周期性心跳；连续失败达到阈值后关闭连接并触发 [disconnected]。
  void startHeartbeat() {
    stopHeartbeat();
    _heartbeatFailures = 0;
    _heartbeatTimer = Timer.periodic(config.heartbeatInterval, (_) {
      unawaited(_runHeartbeatTick());
    });
  }

  /// 停止心跳。
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatFailures = 0;
    _heartbeatInFlight = false;
  }

  /// 发送 JSON 帧，不等待响应（如心跳）。
  void send(WsPacket packet) {
    _ensureAuthenticated();
    _sink.add(jsonEncode(packet.toJson()));
  }

  /// 关闭连接。[intentional] 为 true 时不触发 [disconnected]。
  Future<void> close({bool intentional = true}) async {
    stopHeartbeat();
    final shouldEmitDisconnect =
        !intentional &&
        (_channel != null || _state != WsClientState.disconnected);

    // 关闭过程中一律抑制 _onDone/_onError，由本方法统一决定是否发断线事件。
    _closingIntentionally = true;

    _failPending(const WsException(message: 'connection closed'));
    _authCompleter?.completeError(
      const WsException(message: 'connection closed'),
    );
    _authCompleter = null;

    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // 忽略关闭时的底层异常。
    }
    _channel = null;
    _state = WsClientState.disconnected;
    _closingIntentionally = false;

    if (shouldEmitDisconnect) {
      _notifyDisconnected();
    }
  }

  WebSocketSink get _sink {
    final channel = _channel;
    if (channel == null) {
      throw const WsException(message: 'websocket not connected');
    }
    return channel.sink;
  }

  void _ensureConnected() {
    if (_channel == null || _state == WsClientState.disconnected) {
      throw const WsException(message: 'websocket not connected');
    }
  }

  void _ensureAuthenticated() {
    if (_state != WsClientState.authenticated) {
      throw const WsException(message: 'websocket not authenticated');
    }
  }

  Future<void> _runHeartbeatTick() async {
    if (_heartbeatInFlight || _state != WsClientState.authenticated) return;
    _heartbeatInFlight = true;
    try {
      await ping();
      _heartbeatFailures = 0;
    } catch (_) {
      _heartbeatFailures += 1;
      if (_heartbeatFailures >= config.heartbeatMaxFailures) {
        await close(intentional: false);
      }
    } finally {
      _heartbeatInFlight = false;
    }
  }

  void _onMessage(dynamic message) {
    if (message is String) {
      _handleTextMessage(message);
      return;
    }
    if (message is List<int>) {
      _incomingController.add(WsBinaryMessage(message));
    }
  }

  void _handleTextMessage(String message) {
    final dynamic decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) {
      _incomingController.add(
        WsJsonMessage(
          const WsResponse(
            type: WsFrameType.error,
            code: WsCode.badRequest,
            message: 'invalid json object',
          ),
        ),
      );
      return;
    }

    final response = WsResponse.fromJson(decoded);
    _dispatchJson(response);
  }

  void _dispatchJson(WsResponse response) {
    final authCompleter = _authCompleter;
    if (authCompleter != null && response.type == WsFrameType.authAck) {
      if (!authCompleter.isCompleted) {
        authCompleter.complete(response);
      }
      return;
    }

    final requestId = response.requestId;
    if (requestId != null && requestId.isNotEmpty) {
      final pending = _pending[requestId];
      if (pending != null && !pending.isCompleted) {
        pending.complete(response);
        return;
      }
    }

    _incomingController.add(WsJsonMessage(response));
  }

  void _onError(Object error, [StackTrace? stackTrace]) {
    final wsError = WsException(message: error.toString());
    _failPending(wsError);
    _authCompleter?.completeError(wsError);
    _authCompleter = null;
    _incomingController.addError(wsError, stackTrace);
    stopHeartbeat();
    _state = WsClientState.disconnected;
    _channel = null;
    if (!_closingIntentionally) {
      _notifyDisconnected();
    }
  }

  void _onDone() {
    _failPending(const WsException(message: 'connection closed'));
    _authCompleter?.completeError(
      const WsException(message: 'connection closed'),
    );
    _authCompleter = null;
    stopHeartbeat();
    final wasIntentional = _closingIntentionally;
    _state = WsClientState.disconnected;
    _channel = null;
    if (!wasIntentional) {
      _notifyDisconnected();
    }
  }

  void _notifyDisconnected() {
    if (_disconnectEmitted || _disconnectedController.isClosed) return;
    _disconnectEmitted = true;
    _disconnectedController.add(null);
  }

  void _failPending(WsException error) {
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(error);
      }
    }
    _pending.clear();
  }
}
