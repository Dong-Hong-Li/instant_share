import 'package:instant_share/infrastructure/share_server/share_server_discovery.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';
import 'package:instant_share/infrastructure/websocket/room_ws_models.dart';
import 'package:instant_share/infrastructure/websocket/ws_client.dart';
import 'package:instant_share/infrastructure/websocket/ws_constants.dart';
import 'package:instant_share/infrastructure/websocket/ws_exception.dart';
import 'package:instant_share/infrastructure/websocket/ws_frame.dart';
import 'package:instant_share/infrastructure/websocket/ws_share_models.dart';

/// Admin 端 WebSocket 客户端（Flutter 桌面端：开启/关闭分享）。
class ShareWsAdminClient {
  ShareWsAdminClient({
    WsClient? client,
    ShareServerDiscovery? discovery,
    this.deviceId = 'desktop',
    required Uri serverBaseUri,
  }) : _client = client ?? WsClient(),
       _discovery =
           discovery ?? ShareServerDiscovery(serverBaseUri: serverBaseUri),
       _serverBaseUri = serverBaseUri;

  final WsClient _client;

  final ShareServerDiscovery _discovery;

  final Uri _serverBaseUri;

  /// 设备 ID。
  final String deviceId;

  ShareServerHealthDto? _lastHealth;

  WsClient get client => _client;

  /// 最近一次健康状态。
  ShareServerHealthDto? get lastHealth => _lastHealth;

  Uri get serverBaseUri => _serverBaseUri;

  /// 入站消息流。
  Stream<WsIncomingMessage> get incoming => _client.incoming;

  /// 是否已认证。
  bool get isAuthenticated => _client.isAuthenticated;

  /// 先 HTTP 探测 Go 服务并获取 `ws_url`，再建立 WebSocket 鉴权连接。
  ///
  /// 探测失败会立即抛出 [ShareServerException]，便于 UI 根据 [ShareServerException.message] 提示。
  Future<ShareServerHealthDto> connect({Uri? serverBaseUri}) async {
    final discovery = serverBaseUri != null
        ? ShareServerDiscovery(serverBaseUri: serverBaseUri)
        : _discovery;
    final health = await discovery.fetchHealth();
    _lastHealth = health;
    await _connectWs(Uri.parse(health.wsUrl));
    return health;
  }

  Future<void> _connectWs(Uri wsUri) async {
    await _client.connect(wsUri);
    await _client.authenticate(WsAuthRequest.admin(deviceId: deviceId));
  }

  /// start分享。
  Future<ShareStatusDto> startShare(
    List<ShareFileDto> files, {
    int? port,
  }) async {
    final response = await _client.request(
      WsFrameType.shareStart,
      data: StartShareRequestDto(files: files, port: port).toJson(),
    );
    return _parseShareStatus(response, WsFrameType.shareStartAck);
  }

  /// stop分享。
  Future<ShareStatusDto> stopShare() async {
    final response = await _client.request(WsFrameType.shareStop);
    return _parseShareStatus(response, WsFrameType.shareStopAck);
  }

  /// sync分享。
  Future<ShareStatusDto> syncShare(List<ShareFileDto> files) async {
    final response = await _client.request(
      WsFrameType.shareSync,
      data: StartShareRequestDto(files: files).toJson(),
    );
    return _parseShareStatus(response, WsFrameType.shareSyncAck);
  }

  /// 同步文章内容。
  Future<ShareStatusDto> syncArticles(List<ShareArticleDto> articles) async {
    final response = await _client.request(
      WsFrameType.shareArticleSync,
      data: SyncArticleRequestDto(articles: articles).toJson(),
    );
    return _parseShareStatus(response, WsFrameType.shareArticleSyncAck);
  }

  /// 发送心跳。
  Future<void> ping({String? requestId}) async {
    final response = await _client.request(
      WsFrameType.ping,
      requestId: requestId,
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

  /// 处理配对决定。
  Future<void> decidePairing(String deviceId, {required bool approve}) async {
    final response = await _client.request(
      WsFrameType.pairingDecide,
      data: {'device_id': deviceId, 'approve': approve},
    );
    if (response.type != WsFrameType.pairingDecideAck) {
      throw WsException(
        message: 'unexpected response type: ${response.type}',
        code: response.code,
        frameType: response.type,
        requestId: response.requestId,
      );
    }
    response.ensureSuccess();
  }

  /// fetch房间Snapshot。
  Future<RoomSnapshot> fetchRoomSnapshot() async {
    final response = await _client.request(WsFrameType.roomSnapshot);
    if (response.type != WsFrameType.roomSnapshotAck) {
      throw WsException(
        message: 'unexpected response type: ${response.type}',
        code: response.code,
        frameType: response.type,
        requestId: response.requestId,
      );
    }
    response.ensureSuccess();
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw WsException(
        message: 'invalid room snapshot payload',
        frameType: response.type,
        requestId: response.requestId,
      );
    }
    return RoomSnapshot.fromJson(data);
  }

  Future<void> disconnect() => _client.close();

  ShareStatusDto _parseShareStatus(WsResponse response, String expectedType) {
    if (response.type != expectedType) {
      throw WsException(
        message: 'unexpected response type: ${response.type}',
        code: response.code,
        frameType: response.type,
        requestId: response.requestId,
      );
    }
    response.ensureSuccess();
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw WsException(
        message: 'invalid share status payload',
        frameType: response.type,
        requestId: response.requestId,
      );
    }
    return ShareStatusDto.fromJson(data);
  }
}
