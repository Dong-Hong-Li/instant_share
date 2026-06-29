import 'package:instant_share/features/home/data/home_file_item.dart';
import 'package:instant_share/infrastructure/share_server/share_server_discovery.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';
import 'package:instant_share/infrastructure/websocket/share_ws_admin_client.dart';
import 'package:instant_share/infrastructure/websocket/ws_share_models.dart';

/// 管理 admin WebSocket 与分享会话启停。
class ShareSessionService {
  ShareSessionService({required Uri serverBaseUri})
    : _serverBaseUri = serverBaseUri;

  final Uri _serverBaseUri;
  ShareWsAdminClient? _client;

  Uri get serverBaseUri => _serverBaseUri;

  Future<ShareServerHealthDto> fetchHealth() {
    return ShareServerDiscovery(serverBaseUri: _serverBaseUri).fetchHealth();
  }

  Future<ShareStatusDto> startShare(List<HomeFileItem> files) async {
    final client = await _ensureClient();
    return client.startShare(files.map(_toShareFile).toList());
  }

  Future<ShareStatusDto> stopShare() async {
    final client = await _ensureClient();
    return client.stopShare();
  }

  Future<ShareStatusDto> syncShare(List<HomeFileItem> files) async {
    final client = await _ensureClient();
    return client.syncShare(files.map(_toShareFile).toList());
  }

  Future<ShareStatusDto> syncArticle({
    required String? id,
    required String title,
    required String content,
  }) async {
    final client = await _ensureClient();
    if (id == null) {
      return client.syncArticle(null);
    }
    return client.syncArticle(
      ShareArticleDto(id: id, title: title, content: content),
    );
  }

  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
  }

  Future<ShareWsAdminClient> _ensureClient() async {
    final existing = _client;
    if (existing != null && existing.isAuthenticated) {
      return existing;
    }

    final client = ShareWsAdminClient(serverBaseUri: _serverBaseUri);
    await client.connect();
    _client = client;
    return client;
  }

  ShareFileDto _toShareFile(HomeFileItem file) {
    return ShareFileDto(
      id: file.id,
      path: file.path,
      name: file.name,
      size: file.size,
    );
  }
}
