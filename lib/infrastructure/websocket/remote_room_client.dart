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

  Uri? _peerBaseUrl;
  String? _displayName;
  int _revision = 0;
  StreamSubscription<WsIncomingMessage>? _incomingSub;

  final _notifyController = StreamController<RoomNotifyEvent>.broadcast();
  final _pairingController = StreamController<PairingOutcome>.broadcast();

  Stream<RoomNotifyEvent> get notifies => _notifyController.stream;

  Stream<PairingOutcome> get pairingOutcomes => _pairingController.stream;

  /// 建立连接。
  Future<void> connect({
    required Uri hostWsUrl,
    required String displayName,
    required Uri peerBaseUrl,
  }) async {
    _displayName = displayName;
    _peerBaseUrl = peerBaseUrl;
    await _incomingSub?.cancel();
    _incomingSub = _client.incoming.listen(_handleIncoming);
    await _client.connect(hostWsUrl);
    await _client.authenticate(WsAuthRequest.peer(deviceId: deviceId));
  }

  /// request配对。
  Future<void> requestPairing() async {
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
    );
    if (response.type != WsFrameType.shareOfferAck) {
      throw WsException(message: 'unexpected response type: ${response.type}');
    }
    response.ensureSuccess();
  }

  /// 获取房间快照。
  Future<RoomSnapshot> fetchSnapshot() async {
    final response = await _client.request(WsFrameType.roomSnapshot);
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

  /// 断开连接。
  Future<void> disconnect() async {
    await _incomingSub?.cancel();
    _incomingSub = null;
    await _client.close();
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
