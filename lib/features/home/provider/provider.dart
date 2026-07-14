import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:instant_share/core/controller/share_port_controller.dart';
import 'package:instant_share/core/utils/port/port_util.dart';
import 'package:instant_share/features/home/data/home_article_limits.dart';
import 'package:instant_share/features/home/data/home_article_item.dart';
import 'package:instant_share/features/home/data/home_article_store.dart';
import 'package:instant_share/features/home/data/home_file_item.dart';
import 'package:instant_share/features/home/data/home_share_mode.dart';
import 'package:instant_share/infrastructure/file_picker_manager.dart';
import 'package:instant_share/infrastructure/network/lan_ip_unavailable_exception.dart';
import 'package:instant_share/infrastructure/network/lan_ip_resolver.dart';
import 'package:instant_share/infrastructure/network/share_url_resolver.dart';
import 'package:instant_share/infrastructure/share_server/share_server_config.dart';
import 'package:instant_share/infrastructure/share_server/share_server_health.dart';
import 'package:instant_share/infrastructure/share_server/share_server_host.dart';
import 'package:instant_share/infrastructure/share_server/share_session_service.dart';
import 'package:instant_share/infrastructure/websocket/ws_share_models.dart';
import 'package:state_scope/state_scope.dart';
import 'package:uuid/uuid.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider(this._session, {ShareUrlResolver? shareUrlResolver})
    : _shareUrlResolver = shareUrlResolver ?? ShareUrlResolver(
        lanIpResolver: createLanIpResolver(),
      ) {
    final port = ShareServerHost.instance.port;
    if (port != null) {
      _serverPort = port;
    }
  }

  static const _uuid = Uuid();

  final ShareSessionService _session;
  final ShareUrlResolver _shareUrlResolver;
  final List<HomeFileItem> _selectedFiles = [];
  HomeShareMode _shareMode = HomeShareMode.file;

  bool _syncStarted = false;
  bool _isShareBusy = false;
  bool _isPicking = false;
  bool _isSharing = false;
  String? _shareUrl;
  int? _serverPort;
  String? _serverShareUrl;
  List<String> _alternateShareUrls = const [];
  List<HomeArticleItem> _articles = [];
  final Set<String> _selectedArticleIds = {};
  String? _errorMessage;
  bool _portOccupiedNeedsSettings = false;

  List<HomeFileItem> get selectedFiles => List.unmodifiable(_selectedFiles);

  HomeShareMode get shareMode => _shareMode;

  bool get hasFiles => _selectedFiles.isNotEmpty;

  int get fileCount => _selectedFiles.length;

  int get totalFileSize =>
      _selectedFiles.fold<int>(0, (sum, file) => sum + file.size);

  bool get isPicking => _isPicking;

  bool get isShareBusy => _isShareBusy;

  bool get isSharing => _isSharing;

  List<HomeArticleItem> get articles => List.unmodifiable(_articles);

  Set<String> get selectedArticleIds => Set.unmodifiable(_selectedArticleIds);

  /// 文章是否已被用户选中（本地标记，与服务是否开启无关）。
  bool isArticleSelected(String id) => _selectedArticleIds.contains(id);

  /// 文章是否处于「已分享」展示态（仅服务开启且已选中时为 true）。
  bool isArticleShared(String id) =>
      _isSharing && _selectedArticleIds.contains(id);

  List<HomeArticleItem> get selectedArticles => _articles
      .where((article) => _selectedArticleIds.contains(article.id))
      .toList(growable: false);

  String? get shareUrl => _shareUrl;

  int? get serverPort => _serverPort;

  String? get serverShareUrl => _serverShareUrl;

  List<String> get alternateShareUrls => _alternateShareUrls;

  /// 最近一次分享/地址解析失败的用户可读提示（展示后应 [clearErrorMessage]）。
  String? get errorMessage => _errorMessage;

  /// 自定义端口占用，需引导用户去设置页。
  bool get portOccupiedNeedsSettings => _portOccupiedNeedsSettings;

  void clearErrorMessage() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void clearPortOccupiedFlag() {
    if (!_portOccupiedNeedsSettings) return;
    _portOccupiedNeedsSettings = false;
    notifyListeners();
  }

  void _setErrorMessage(String? message) {
    if (_errorMessage == message) return;
    _errorMessage = message;
  }

  bool get hasServerInfo =>
      _serverPort != null ||
      (_serverShareUrl != null && _serverShareUrl!.isNotEmpty);

  /// 复制局域网分享地址（主地址）。
  Future<bool> copyServerShareUrl() async {
    final url = _serverShareUrl;
    if (url == null || url.isEmpty) return false;
    return copyShareUrlToClipboard(url);
  }

  /// 复制指定分享地址到剪贴板。
  Future<bool> copyShareUrlToClipboard(String url) async {
    if (url.trim().isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: url.trim()));
    return true;
  }

  /// 复制当前分享链接到剪贴板。
  Future<bool> copyShareUrl() async {
    final url = _shareUrl;
    if (url == null || url.isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: url));
    return true;
  }

  void setShareMode(HomeShareMode mode) {
    if (_shareMode == mode) return;
    _shareMode = mode;
    notifyListeners();
  }

  /// 创建文章；正文为空或超过 [HomeArticleLimits.maxContentLength] 时返回 null。
  Future<HomeArticleItem?> createArticle({
    required String title,
    required String content,
  }) async {
    final body = content.trim();
    if (!HomeArticleLimits.isContentLengthValid(body)) return null;

    final article = HomeArticleItem(
      id: _uuid.v4(),
      title: title.trim(),
      content: body,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _articles.insert(0, article);
    await _persistArticles();
    notifyListeners();
    return article;
  }

  Future<void> removeArticle(String id) async {
    final index = _articles.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _articles.removeAt(index);

    final wasSelected = _selectedArticleIds.remove(id);

    await _persistArticles();
    if (wasSelected && _isSharing) {
      await _syncSharedArticlesToServer();
    }
    notifyListeners();
  }

  Future<bool> copyArticleContent(String id) async {
    HomeArticleItem? target;
    for (final article in _articles) {
      if (article.id == id) {
        target = article;
        break;
      }
    }
    if (target == null) return false;

    await Clipboard.setData(ClipboardData(text: target.content));
    return true;
  }

  /// 切换文章选中态；服务开启时会同步到接收端。
  ///
  /// 返回切换后的选中态；文章不存在时返回 null。
  Future<bool?> toggleArticleShared(String id) async {
    final exists = _articles.any((item) => item.id == id);
    if (!exists) return null;

    if (_selectedArticleIds.contains(id)) {
      _selectedArticleIds.remove(id);
    } else {
      final article = _articles.firstWhere((item) => item.id == id);
      if (article.charCount > HomeArticleLimits.maxContentLength) {
        return null;
      }
      _selectedArticleIds.add(id);
    }

    await _persistArticles();
    notifyListeners();
    if (_isSharing) {
      await _syncSharedArticlesToServer();
    }
    return _selectedArticleIds.contains(id);
  }

  /// 启动时同步：若 Go 端仍有遗留分享会话则自动 stop；恢复本地文章列表。
  Future<void> syncOnStartup() async {
    if (_syncStarted) return;
    _syncStarted = true;

    try {
      await _loadArticlesFromStorage();

      final health = await _session.fetchHealth();
      await _applyServerHealth(health);

      if (health.share.active) {
        await _session.stopShare();
        _isSharing = false;
        _shareUrl = null;
      }
      notifyListeners();
    } catch (error, stackTrace) {
      _handleShareError(error);
      debugPrint('[HomeProvider] syncOnStartup failed: $error\n$stackTrace');
    }
  }

  Future<void> _loadArticlesFromStorage() async {
    final snapshot = await HomeArticleStore.load();
    _articles = List<HomeArticleItem>.from(snapshot.articles);
    _selectedArticleIds
      ..clear()
      ..addAll(snapshot.sharedArticleIds);

    final validIds = _articles.map((item) => item.id).toSet();
    _selectedArticleIds.removeWhere((id) => !validIds.contains(id));
  }

  Future<void> _persistArticles() {
    return HomeArticleStore.save(
      articles: _articles,
      sharedArticleIds: _selectedArticleIds,
    );
  }

  Future<void> _applyServerHealth(ShareServerHealthDto health) async {
    _serverPort = health.port;
    try {
      final resolved = await _shareUrlResolver.resolveFromHealth(health);
      _serverShareUrl = resolved.primaryUrl;
      _alternateShareUrls = resolved.alternateUrls;
      _setErrorMessage(null);
    } catch (error) {
      _serverShareUrl = null;
      _alternateShareUrls = const [];
      _handleShareError(error);
    }
  }

  /// 切换分享开关（开始 / 停止分享）。
  Future<void> toggleSharing() async {
    if (_isShareBusy) return;
    if (_isSharing) {
      await _stopSharing();
    } else {
      await _startSharing();
    }
  }

  /// 退出应用前尽力关闭分享。
  Future<void> stopSharingIfNeeded() async {
    if (!_isSharing) return;

    try {
      await _session.stopShare();
    } catch (error, stackTrace) {
      debugPrint(
        '[HomeProvider] stopSharingIfNeeded failed: $error\n$stackTrace',
      );
    } finally {
      _isSharing = false;
      _shareUrl = null;
    }
  }

  Future<String> _resolveShareUrlAsync(ShareStatusDto status) async {
    final resolved = await _shareUrlResolver.resolveFromStatus(status);
    return resolved.primaryUrl;
  }

  void _handleShareError(Object error) {
    final message = switch (error) {
      LanIpUnavailableException(:final message) => message,
      _ => error.toString(),
    };
    _setErrorMessage(message);
    notifyListeners();
  }

  Future<void> pickFiles() async {
    if (_isPicking) return;

    _isPicking = true;
    notifyListeners();

    try {
      final result = await FilePickerManager.pickFiles();

      if (result.isEmpty) return;

      final existingPaths = _selectedFiles.map((file) => file.path).toSet();
      var changed = false;

      for (final picked in result) {
        final path = picked.path;
        if (path.isEmpty || existingPaths.contains(path)) {
          continue;
        }

        final file = File(path);
        if (!file.existsSync()) continue;

        final size = file.lengthSync();
        _selectedFiles.insert(
          0,
          HomeFileItem(
            id: _uuid.v4(),
            path: path,
            name: file.path.split(Platform.pathSeparator).last,
            size: size,
          ),
        );
        existingPaths.add(path);
        changed = true;
      }

      if (changed) {
        if (_isSharing) {
          await _syncSharingFiles();
        }
        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint('[HomeProvider] pickFiles failed: $error\n$stackTrace');
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }

  Future<void> removeFile(String id) async {
    final index = _selectedFiles.indexWhere((file) => file.id == id);
    if (index == -1) return;
    _selectedFiles.removeAt(index);

    if (_selectedFiles.isEmpty && _isSharing) {
      await _syncSharingFiles();
      notifyListeners();
    } else {
      if (_isSharing) {
        await _syncSharingFiles();
      }
      notifyListeners();
    }
  }

  Future<void> clearFiles() async {
    if (_selectedFiles.isEmpty) return;
    _selectedFiles.clear();

    if (_isSharing) {
      await _syncSharingFiles();
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_shutdown());
    super.dispose();
  }

  Future<void> _startSharing() async {
    _isShareBusy = true;
    notifyListeners();

    try {
      final blocked = await _guardCustomPortBeforeStart();
      if (blocked) return;

      final status = await _session.startShare(_selectedFiles);
      if (!status.active) {
        _isSharing = false;
        _shareUrl = null;
        return;
      }

      try {
        _shareUrl = await _resolveShareUrlAsync(status);
        _isSharing = true;
        _setErrorMessage(null);
        if (_selectedArticleIds.isNotEmpty) {
          await _syncSharedArticlesToServer();
        }
      } catch (error) {
        await _session.stopShare();
        _isSharing = false;
        _shareUrl = null;
        _handleShareError(error);
      }
    } catch (error, stackTrace) {
      _isSharing = false;
      _shareUrl = null;
      _handleShareError(error);
      debugPrint('[HomeProvider] startShare failed: $error\n$stackTrace');
    } finally {
      _isShareBusy = false;
      notifyListeners();
    }
  }

  /// 自定义端口守卫；返回 true 表示已拦截、不应继续 startShare。
  Future<bool> _guardCustomPortBeforeStart() async {
    final portCtrl = DI.find<SharePortController>();
    if (!portCtrl.useCustomPort) return false;

    final port = portCtrl.customPort;
    if (port == null || !PortUtil.isValidCustomPort(port)) {
      _setErrorMessage(
        '请设置合法的自定义端口（${PortUtil.kMinCustomSharePort}–${PortUtil.kMaxCustomSharePort}）',
      );
      return true;
    }

    final currentListen = ShareServerHost.instance.port;
    final free = await PortUtil.isPortFree(
      port,
      ownedByCurrentServer: currentListen,
    );
    if (!free) {
      _portOccupiedNeedsSettings = true;
      return true;
    }

    return false;
  }

  /// 分享服务端口重绑后：换 session 基址并刷新 health。
  Future<void> rebindAfterServerRestart() async {
    final port = ShareServerHost.instance.port;
    if (port == null) {
      _serverPort = null;
      _serverShareUrl = null;
      _alternateShareUrls = const [];
      await _session.disconnect();
      notifyListeners();
      return;
    }

    await _session.rebind(ShareServerConfig.baseUriForPort(port));
    _serverPort = port;
    try {
      final health = await _session.fetchHealth();
      await _applyServerHealth(health);
    } catch (error, stackTrace) {
      debugPrint(
        '[HomeProvider] rebindAfterServerRestart health failed: $error\n$stackTrace',
      );
      _handleShareError(error);
    }
    notifyListeners();
  }

  Future<void> _stopSharing() async {
    _isShareBusy = true;
    notifyListeners();

    try {
      await _session.stopShare();
      _isSharing = false;
      _shareUrl = null;
    } catch (error, stackTrace) {
      debugPrint('[HomeProvider] stopShare failed: $error\n$stackTrace');
    } finally {
      _isShareBusy = false;
      notifyListeners();
    }
  }

  Future<void> _syncSharingFiles() async {
    try {
      await _session.syncShare(_selectedFiles);
    } catch (error, stackTrace) {
      debugPrint('[HomeProvider] syncShare failed: $error\n$stackTrace');
    }
  }

  Future<void> _syncSharedArticlesToServer() async {
    if (!_isSharing) return;

    try {
      final articles = selectedArticles
          .where(
            (article) =>
                article.charCount <= HomeArticleLimits.maxContentLength,
          )
          .map(
            (article) => ShareArticleDto(
              id: article.id,
              title: article.title,
              content: article.content,
            ),
          )
          .toList();
      await _session.syncArticles(articles);
    } catch (error, stackTrace) {
      debugPrint('[HomeProvider] syncArticles failed: $error\n$stackTrace');
    }
  }

  Future<void> _shutdown() async {
    await stopSharingIfNeeded();
    await _session.disconnect();
  }
}

final homeProvider = ChangeNotifierProvider<HomeProvider>((ref) {
  // 服务未启动时 port 为 null；用占位 URI，避免 provider 创建即崩溃。
  final port = ShareServerHost.instance.port;
  final provider = HomeProvider(
    ShareSessionService(
      serverBaseUri: ShareServerConfig.baseUriForPort(port ?? 0),
    ),
  );
  ref.onDispose(provider.dispose);
  if (port != null) {
    scheduleMicrotask(provider.syncOnStartup);
  }
  return provider;
});
