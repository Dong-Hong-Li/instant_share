import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:instant_share/features/home/data/home_file_item.dart';
import 'package:instant_share/features/home/data/home_share_mode.dart';
import 'package:instant_share/infrastructure/file_picker_manager.dart';
import 'package:instant_share/infrastructure/share_server/share_session_service.dart';
import 'package:instant_share/infrastructure/websocket/ws_share_models.dart';
import 'package:uuid/uuid.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider(this._session);

  static const _uuid = Uuid();

  final ShareSessionService _session;
  final List<HomeFileItem> _selectedFiles = [];
  HomeShareMode _shareMode = HomeShareMode.file;

  bool _syncStarted = false;
  bool _isShareBusy = false;
  bool _isPicking = false;
  bool _isSharing = false;
  String? _shareUrl;

  List<HomeFileItem> get selectedFiles => List.unmodifiable(_selectedFiles);

  HomeShareMode get shareMode => _shareMode;

  bool get hasFiles => _selectedFiles.isNotEmpty;

  int get fileCount => _selectedFiles.length;

  int get totalFileSize =>
      _selectedFiles.fold<int>(0, (sum, file) => sum + file.size);

  bool get isPicking => _isPicking;

  bool get isShareBusy => _isShareBusy;

  bool get isSharing => _isSharing;

  String? get shareUrl => _shareUrl;

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

  /// 启动时同步：若 Go 端仍有遗留分享会话则自动 stop。
  Future<void> syncOnStartup() async {
    if (_syncStarted) return;
    _syncStarted = true;

    try {
      final cleared = await _session.clearStaleSession();
      if (cleared) {
        _isSharing = false;
        _shareUrl = null;
        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint('[HomeProvider] syncOnStartup failed: $error\n$stackTrace');
    }
  }

  /// 切换分享开关（开始 / 停止分享）。
  Future<void> toggleSharing() async {
    if (!hasFiles || _isShareBusy) return;
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

  String? _resolveShareUrl(ShareStatusDto status) {
    final baseUrl = status.baseUrl?.trim();
    if (baseUrl != null && baseUrl.isNotEmpty) return baseUrl;

    final ip = status.ip?.trim();
    final port = status.port;
    if (ip != null && ip.isNotEmpty && port != null) {
      return 'http://$ip:$port/share';
    }
    return null;
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

      if (changed) notifyListeners();
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
      await _stopSharing();
    } else {
      notifyListeners();
    }
  }

  Future<void> clearFiles() async {
    if (_selectedFiles.isEmpty) return;
    _selectedFiles.clear();

    if (_isSharing) {
      await _stopSharing();
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
      final status = await _session.startShare(_selectedFiles);
      _isSharing = status.active;
      _shareUrl = _resolveShareUrl(status);
    } catch (error, stackTrace) {
      _isSharing = false;
      _shareUrl = null;
      debugPrint('[HomeProvider] startShare failed: $error\n$stackTrace');
    } finally {
      _isShareBusy = false;
      notifyListeners();
    }
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

  Future<void> _shutdown() async {
    await stopSharingIfNeeded();
    await _session.disconnect();
  }
}

final homeProvider = ChangeNotifierProvider<HomeProvider>((ref) {
  final provider = HomeProvider(ShareSessionService());
  ref.onDispose(provider.dispose);
  scheduleMicrotask(provider.syncOnStartup);
  return provider;
});
