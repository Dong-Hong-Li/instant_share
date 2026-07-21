import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:instant_share/core/controller/share_port_controller.dart';
import 'package:instant_share/core/utils/port/port_util.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/features/setting/data/setting_port_messages.dart';
import 'package:instant_share/infrastructure/share_server/share_server_host.dart';
import 'package:state_scope/state_scope.dart';

/// 保存 / 重绑操作结果，由 UI 层决定是否弹 SnackBar。
enum SettingPortApplyResult { noop, saved, rebindOk, rebindFailed }

/// 设置页 UI 状态与编排（全局端口配置仍由 [SharePortController] 持有）。
class SettingProvider extends ChangeNotifier {
  SettingProvider(this._ref) {
    _portController = DI.find<SharePortController>();
    _lastFocusRequestId = _portController.focusPortRequestId;
    _expanded = _portController.useCustomPort;
    _draftPortText = _portController.customPort?.toString() ?? '';
    _portController.addListener(_onPortControllerChanged);
  }

  final Ref _ref;

  late final SharePortController _portController;

  bool _expanded = false;
  String _draftPortText = '';
  String? _fieldError;
  String? _checkMessage;
  bool _checkOk = false;
  bool _checking = false;
  bool _rebinding = false;
  bool _portFieldFocused = false;
  int _lastFocusRequestId = 0;
  int _focusTick = 0;

  /// 是否展开。
  bool get expanded => _expanded;

  String get draftPortText => _draftPortText;

  /// 输入框错误。
  String? get fieldError => _fieldError;

  /// 检测消息。
  String? get checkMessage => _checkMessage;

  /// 检测是否通过。
  bool get checkOk => _checkOk;

  /// 是否正在检测。
  bool get checking => _checking;

  /// 是否正在重绑端口。
  bool get rebinding => _rebinding;

  int get focusTick => _focusTick;

  /// isDirty。
  bool get isDirty {
    final current = _draftPortText.trim();
    final saved = _portController.customPort?.toString() ?? '';
    return current != saved;
  }

  /// isEnabled。
  bool isEnabled(bool isSharing) => !isSharing && !_rebinding;

  /// setPortFieldFocused。
  void setPortFieldFocused(bool focused) {
    _portFieldFocused = focused;
  }

  /// onDraftChanged。
  void onDraftChanged(String value) {
    if (_draftPortText == value) return;
    _draftPortText = value;
    _checkMessage = null;
    notifyListeners();
  }

  /// onToggle。
  Future<SettingPortApplyResult> onToggle({
    required bool enabled,
    required bool isSharing,
  }) async {
    if (!isEnabled(isSharing)) return SettingPortApplyResult.noop;

    if (!enabled) {
      final changed = _portController.useCustomPort;
      _expanded = false;
      _fieldError = null;
      _checkMessage = null;
      notifyListeners();
      if (changed) {
        return _persistAndRebind(_portController.saveSystemAllocation);
      }
      await _portController.saveSystemAllocation();
      return SettingPortApplyResult.saved;
    }

    _expanded = true;
    notifyListeners();

    final existing = _portController.customPort;
    if (existing != null && PortUtil.isValidCustomPort(existing)) {
      return _persistAndRebind(() => _portController.saveCustomPort(existing));
    }

    _fieldError = SettingPortMessages.invalidPort;
    notifyListeners();
    return SettingPortApplyResult.noop;
  }

  /// savePort。
  Future<SettingPortApplyResult> savePort({required bool isSharing}) async {
    if (!isEnabled(isSharing)) return SettingPortApplyResult.noop;

    final port = int.tryParse(_draftPortText.trim());
    if (port == null || !PortUtil.isValidCustomPort(port)) {
      _fieldError = SettingPortMessages.invalidPort;
      _checkMessage = null;
      notifyListeners();
      return SettingPortApplyResult.noop;
    }

    final previous = _portController.customPort;
    final wasCustom = _portController.useCustomPort;
    final shouldRebind = !wasCustom || previous != port;

    _fieldError = null;
    _checkMessage = null;
    notifyListeners();

    if (!shouldRebind) {
      await _portController.saveCustomPort(port);
      return SettingPortApplyResult.saved;
    }

    return _persistAndRebind(() => _portController.saveCustomPort(port));
  }

  /// checkPort。
  Future<void> checkPort({required bool isSharing}) async {
    if (!isEnabled(isSharing) || _checking) return;

    final port = int.tryParse(_draftPortText.trim());
    if (port == null || !PortUtil.isValidCustomPort(port)) {
      _fieldError = SettingPortMessages.invalidPort;
      _checkMessage = null;
      notifyListeners();
      return;
    }

    _checking = true;
    _fieldError = null;
    _checkMessage = null;
    notifyListeners();

    final free = await PortUtil.isPortFree(
      port,
      ownedByCurrentServer: ShareServerHost.instance.port,
    );

    _checking = false;
    _checkOk = free;
    _checkMessage = free
        ? SettingPortMessages.portAvailable
        : SettingPortMessages.portUnavailable;
    notifyListeners();
  }

  void _onPortControllerChanged() {
    final requestId = _portController.focusPortRequestId;
    if (requestId != _lastFocusRequestId) {
      _lastFocusRequestId = requestId;
      _expanded = true;
      _focusTick++;
    }
    if (!_portFieldFocused) {
      _draftPortText = _portController.customPort?.toString() ?? '';
    }
    // 与原先 Widget 行为一致：最终展开态跟随全局开关。
    _expanded = _portController.useCustomPort;
    notifyListeners();
  }

  Future<SettingPortApplyResult> _persistAndRebind(
    Future<bool> Function() persist,
  ) async {
    final saved = await persist();
    if (!saved) return SettingPortApplyResult.noop;

    _rebinding = true;
    notifyListeners();
    try {
      await ShareServerHost.instance.restartListening();
      await _ref.read(homeProvider).rebindAfterServerRestart();
      return SettingPortApplyResult.rebindOk;
    } catch (error, stackTrace) {
      debugPrint('[SettingProvider] rebind failed: $error\n$stackTrace');
      return SettingPortApplyResult.rebindFailed;
    } finally {
      _rebinding = false;
      _expanded = _portController.useCustomPort;
      if (!_portFieldFocused) {
        _draftPortText = _portController.customPort?.toString() ?? '';
      }
      notifyListeners();
    }
  }

  /// 释放资源。
  @override
  void dispose() {
    _portController.removeListener(_onPortControllerChanged);
    super.dispose();
  }
}

/// setting状态。
final settingProvider = ChangeNotifierProvider<SettingProvider>((ref) {
  /// 状态提供者。
  final provider = SettingProvider(ref);
  ref.onDispose(provider.dispose);
  return provider;
});
