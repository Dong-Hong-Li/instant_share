import 'dart:async';

import 'package:instant_share/infrastructure/websocket/room_ws_models.dart';
import 'package:instant_share/infrastructure/websocket/ws_client.dart';
import 'package:instant_share/infrastructure/websocket/ws_constants.dart';
import 'package:instant_share/infrastructure/websocket/ws_exception.dart';
import 'package:instant_share/infrastructure/websocket/ws_frame.dart';

/// Remote房间客户端。
class RemoteRoomClient {
  RemoteRoomClient({WsClient? client, required this.deviceId})
    : _client = client ?? WsClient();

  final WsClient _client;

  /// 设备 ID。
  final String deviceId;

  Uri? _hostWsUrl;
  Uri? _peerBaseUrl;
  String? _displayName;
  int _revision = 0;
  StreamSubscription<WsIncomingMessage>? _incomingSub;
  StreamSubscription<void>? _disconnectedSub;

  final _notifyController = StreamController<RoomNotifyEvent>.broadcast();
  final _pairingController = StreamController<PairingOutcome>.broadcast();
  final _disconnectedController = StreamController<void>.broadcast();

  /// 是否主动断开（disconnect / 重连前 teardown），用于过滤误报。
  bool _suppressDisconnect = false;

  Stream<RoomNotifyEvent> get notifies => _notifyController.stream;

  Stream<PairingOutcome> get pairingOutcomes => _pairingController.stream;

  /// 非主动关闭导致的断线（供上层短时重连）。
  Stream<void> get disconnected => _disconnectedController.stream;

  /// 建立连接。
  Future<void> connect({
    required Uri hostWsUrl,
    required String displayName,
    required Uri peerBaseUrl,
  }) async {
    _displayName = displayName;
    _peerBaseUrl = peerBaseUrl;
    _hostWsUrl = hostWsUrl;
    await _bindClient();
    await _client.connect(hostWsUrl);
    await _client.authenticate(WsAuthRequest.peer(deviceId: deviceId));
  }

  /// 使用缓存参数重连并鉴权，不发起配对申请。
  Future<void> reconnect() async {
    final hostWsUrl = _hostWsUrl;
    final displayName = _displayName;
    final peerBaseUrl = _peerBaseUrl;
    if (hostWsUrl == null || displayName == null || peerBaseUrl == null) {
      throw const WsException(message: 'reconnect params are not ready');
    }
    _suppressDisconnect = true;
    try {
      await _client.close(intentional: true);
    } finally {
      _suppressDisconnect = false;
    }
    await _bindClient();
    await _client.connect(hostWsUrl);
    await _client.authenticate(WsAuthRequest.peer(deviceId: deviceId));
  }

  /// 入房后启动业务心跳。
  void startHeartbeat() => _client.startHeartbeat();

  /// 停止业务心跳。
  void stopHeartbeat() => _client.stopHeartbeat();

  /// request配对。
  ///
  /// 返回 `true` 表示 Host 侧仍保留该成员（断线宽限期内重连），已自动入房。
  Future<bool> requestPairing() async {
    final peerBaseUrl = _peerBaseUrl;
    if (peerBaseUrl == null) {
      throw const WsException(message: 'peer base url is not ready');
    }
    final response = await _client.request(
      WsFrameType.pairingRequest,
      data: {
        'device_id': deviceId,
        'display_name': _displayName ?? deviceId,
        'peer_base_url': peerBaseUrl.toString(),
      },
      timeout: const Duration(seconds: 10),
    );
    if (response.type != WsFrameType.pairingRequestAck) {
      throw WsException(
        message: 'unexpected response type: ${response.type}',
        frameType: response.type,
        requestId: response.requestId,
      );
    }
    response.ensureSuccess();
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data['rejoined'] == true;
    }
    return false;
  }

  /// 提交共享文件。
  Future<void> offerFiles(List<RoomFileOffer> files) async {
    final peerBaseUrl = _peerBaseUrl;
    if (peerBaseUrl == null) return;
    final response = await _client.request(
      WsFrameType.shareOffer,
      data: {
        'owner_id': deviceId,
        'base_url': peerBaseUrl.toString(),
        'files': files.map((file) => file.toJson()).toList(),
        'revision': ++_revision,
      },
      timeout: const Duration(seconds: 10),
    );
    if (response.type != WsFrameType.shareOfferAck) {
      throw WsException(message: 'unexpected response type: ${response.type}');
    }
    response.ensureSuccess();
  }

  /// 获取房间快照。
  Future<RoomSnapshot> fetchSnapshot() async {
    final response = await _client.request(
      WsFrameType.roomSnapshot,
      timeout: const Duration(seconds: 10),
    );
    if (response.type != WsFrameType.roomSnapshotAck) {
      throw WsException(message: 'unexpected response type: ${response.type}');
    }
    response.ensureSuccess();
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const WsException(message: 'invalid room snapshot payload');
    }
    return RoomSnapshot.fromJson(data);
  }

  /// 主动离房（通知 Host 移除成员；断线前调用）。
  Future<void> leaveRoom() async {
    if (!_client.isAuthenticated) return;
    final response = await _client.request(
      WsFrameType.roomLeave,
      timeout: const Duration(seconds: 5),
    );
    if (response.type != WsFrameType.roomLeaveAck) {
      throw WsException(message: 'unexpected response type: ${response.type}');
    }
    response.ensureSuccess();
  }

  /// 撤回待审批配对申请（断线前调用；Host 侧清除 pending）。
  Future<void> cancelPairingRequest() async {
    if (!_client.isAuthenticated) return;
    final response = await _client.request(
      WsFrameType.pairingCancel,
      timeout: const Duration(seconds: 5),
    );
    if (response.type != WsFrameType.pairingCancelAck) {
      throw WsException(message: 'unexpected response type: ${response.type}');
    }
    response.ensureSuccess();
  }

  /// 断开连接。
  Future<void> disconnect() async {
    stopHeartbeat();
    _suppressDisconnect = true;
    try {
      await _disconnectedSub?.cancel();
      _disconnectedSub = null;
      await _incomingSub?.cancel();
      _incomingSub = null;
      await _client.close(intentional: true);
    } finally {
      _suppressDisconnect = false;
    }
  }

  Future<void> _bindClient() async {
    await _incomingSub?.cancel();
    _incomingSub = _client.incoming.listen(_handleIncoming);
    await _disconnectedSub?.cancel();
    _disconnectedSub = _client.disconnected.listen((_) {
      if (_suppressDisconnect) return;
      stopHeartbeat();
      if (!_disconnectedController.isClosed) {
        _disconnectedController.add(null);
      }
    });
  }

  void _handleIncoming(WsIncomingMessage message) {
    if (message is! WsJsonMessage) return;
    final response = message.response;
    if (!response.isSuccess) return;
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : const <String, dynamic>{};

    switch (response.type) {
      case WsFrameType.pairingApprove:
        _pairingController.add(
          PairingOutcome(
            PairingOutcomeType.approved,
            hostBaseUrl: data['host_base_url'] as String?,
            roomId: data['room_id'] as String?,
          ),
        );
      case WsFrameType.pairingReject:
        _pairingController.add(
          const PairingOutcome(PairingOutcomeType.rejected),
        );
      case WsFrameType.pairingTimeout:
        _pairingController.add(
          const PairingOutcome(PairingOutcomeType.timeout),
        );
      case WsFrameType.roomNotify:
        _notifyController.add(RoomNotifyEvent.fromJson(data));
    }
  }
}
