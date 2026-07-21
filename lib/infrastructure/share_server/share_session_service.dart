import 'dart:async';

import 'package:instant_share/features/home/data/home_file_item.dart';
import 'package:instant_share/infrastructure/share_server/share_server_discovery.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';
import 'package:instant_share/infrastructure/websocket/room_ws_models.dart';
import 'package:instant_share/infrastructure/websocket/share_ws_admin_client.dart';
import 'package:instant_share/infrastructure/websocket/ws_frame.dart';
import 'package:instant_share/infrastructure/websocket/ws_share_models.dart';

/// 管理 admin WebSocket 与分享会话启停。
///
/// Host 侧全局应只持有一份实例：Go 端按 `uid=admin` 单连接，重复 connect 会踢掉旧连接。
class ShareSessionService {
  ShareSessionService({required Uri serverBaseUri})
    : _serverBaseUri = serverBaseUri;

  Uri _serverBaseUri;
  ShareWsAdminClient? _client;
  Future<ShareWsAdminClient>? _ensureFuture;

  Uri get serverBaseUri => _serverBaseUri;

  /// 断开旧连接并切换服务基址（端口重绑后调用）。
  Future<void> rebind(Uri serverBaseUri) async {
    await disconnect();
    _serverBaseUri = serverBaseUri;
  }

  /// 获取服务健康状态。
  Future<ShareServerHealthDto> fetchHealth() {
    return ShareServerDiscovery(serverBaseUri: _serverBaseUri).fetchHealth();
  }

  /// start分享。
  Future<ShareStatusDto> startShare(List<HomeFileItem> files) async {
    final client = await _ensureClient();
    return client.startShare(files.map(_toShareFile).toList());
  }

  /// stop分享。
  Future<ShareStatusDto> stopShare() async {
    final client = await _ensureClient();
    return client.stopShare();
  }

  /// sync分享。
  Future<ShareStatusDto> syncShare(List<HomeFileItem> files) async {
    final client = await _ensureClient();
    return client.syncShare(files.map(_toShareFile).toList());
  }

  /// 同步文章内容。
  Future<ShareStatusDto> syncArticles(List<ShareArticleDto> articles) async {
    final client = await _ensureClient();
    return client.syncArticles(articles);
  }

  /// 断开连接。
  Future<void> disconnect() async {
    _ensureFuture = null;
    await _client?.disconnect();
    _client = null;
  }

  Future<ShareWsAdminClient> ensureAdminClient() => _ensureClient();

  /// 入站消息流。
  Stream<WsIncomingMessage> get incoming async* {
    final client = await _ensureClient();
    yield* client.incoming;
  }

  /// fetch房间Snapshot。
  Future<RoomSnapshot> fetchRoomSnapshot() async {
    final client = await _ensureClient();
    return client.fetchRoomSnapshot();
  }

  /// 处理配对决定。
  Future<void> decidePairing(String deviceId, {required bool approve}) async {
    final client = await _ensureClient();
    return client.decidePairing(deviceId, approve: approve);
  }

  /// 同步公共房间目录到本机 Go（Peer 侧镜像，供 `/share` 使用）。
  Future<void> syncPublicRoomCatalog(List<SharedEntryDto> catalog) async {
    final client = await _ensureClient();
    return client.syncPublicRoomCatalog(catalog);
  }

  /// 清空本机 Go 上的公共房间目录镜像。
  Future<void> clearPublicRoomCatalog() async {
    final client = await _ensureClient();
    return client.clearPublicRoomCatalog();
  }

  Future<ShareWsAdminClient> _ensureClient() async {
    final existing = _client;
    if (existing != null && existing.isAuthenticated) {
      return existing;
    }

    final inFlight = _ensureFuture;
    if (inFlight != null) return inFlight;

    final future = _connectClient();
    _ensureFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_ensureFuture, future)) {
        _ensureFuture = null;
      }
    }
  }

  Future<ShareWsAdminClient> _connectClient() async {
    final existing = _client;
    if (existing != null && existing.isAuthenticated) {
      return existing;
    }

    await existing?.disconnect();
    _client = null;

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
