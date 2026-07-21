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
  });

  /// 连接超时。
  final Duration connectTimeout;

  /// 请求超时。
  final Duration requestTimeout;
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

  Completer<WsResponse>? _authCompleter;
  WsClientState _state = WsClientState.disconnected;

  /// 连接状态。
  WsClientState get state => _state;

  /// 入站消息流。
  Stream<WsIncomingMessage> get incoming => _incomingController.stream;

  /// 是否已认证。
  bool get isAuthenticated => _state == WsClientState.authenticated;

  /// 建立 WebSocket 连接（尚未鉴权）。
  Future<void> connect(Uri uri) async {
    await close();
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

  /// 发送 JSON 帧，不等待响应（如心跳）。
  void send(WsPacket packet) {
    _ensureAuthenticated();
    _sink.add(jsonEncode(packet.toJson()));
  }

  /// close。
  Future<void> close() async {
    _failPending(const WsException(message: 'connection closed'));
    _authCompleter?.completeError(
      const WsException(message: 'connection closed'),
    );
    _authCompleter = null;

    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _state = WsClientState.disconnected;
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
  }

  void _onDone() {
    _failPending(const WsException(message: 'connection closed'));
    _authCompleter?.completeError(
      const WsException(message: 'connection closed'),
    );
    _authCompleter = null;
    _state = WsClientState.disconnected;
    _channel = null;
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
