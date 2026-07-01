import 'package:instant_share/infrastructure/share_server/share_server_discovery.dart';
import 'package:instant_share/infrastructure/share_server/share_server_exception.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';
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
  final String deviceId;

  ShareServerHealthDto? _lastHealth;

  WsClient get client => _client;

  ShareServerHealthDto? get lastHealth => _lastHealth;

  Uri get serverBaseUri => _serverBaseUri;

  Stream<WsIncomingMessage> get incoming => _client.incoming;

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

  Future<ShareStatusDto> stopShare() async {
    final response = await _client.request(WsFrameType.shareStop);
    return _parseShareStatus(response, WsFrameType.shareStopAck);
  }

  Future<ShareStatusDto> syncShare(List<ShareFileDto> files) async {
    final response = await _client.request(
      WsFrameType.shareSync,
      data: StartShareRequestDto(files: files).toJson(),
    );
    return _parseShareStatus(response, WsFrameType.shareSyncAck);
  }

  Future<ShareStatusDto> syncArticles(List<ShareArticleDto> articles) async {
    final response = await _client.request(
      WsFrameType.shareArticleSync,
      data: SyncArticleRequestDto(articles: articles).toJson(),
    );
    return _parseShareStatus(response, WsFrameType.shareArticleSyncAck);
  }

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
