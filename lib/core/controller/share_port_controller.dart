import 'package:instant_share/core/utils/port/port_util.dart';
import 'package:instant_share/core/utils/storage/prefs_util.dart';
import 'package:instant_share/resource/keys.dart';
import 'package:state_scope/state_scope.dart';

/// 全局自定义分享端口配置（DI 单例）。
class SharePortController extends AppController {
  bool _useCustomPort = false;
  int? _customPort;
  int _focusPortRequestId = 0;
  bool _navigateToSettings = false;

  /// 是否使用自定义端口。
  bool get useCustomPort => _useCustomPort;

  /// 自定义端口。
  int? get customPort => _customPort;

  /// 聚焦端口请求 ID。
  int get focusPortRequestId => _focusPortRequestId;

  /// 冷启动应绑定的监听端口；非自定义或非法时返回 null（调用方用系统分配）。
  int? get listenPortOrNull {
    if (!_useCustomPort) return null;
    final port = _customPort;
    if (port == null || !PortUtil.isValidCustomPort(port)) return null;
    return port;
  }

  /// 初始化控制器。
  @override
  void onInit() {
    super.onInit();
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    _useCustomPort = PrefsUtil.getBool(AppKeys.shareUseCustomPort) ?? false;
    final stored = PrefsUtil.getInt(AppKeys.shareCustomPort);
    if (stored != null && PortUtil.isValidCustomPort(stored)) {
      _customPort = stored;
    } else {
      _customPort = null;
      if (_useCustomPort) {
        _useCustomPort = false;
      }
    }
  }

  /// 关闭自定义端口并持久化。返回是否写入成功（用于弹重启引导）。
  Future<bool> saveSystemAllocation() async {
    _useCustomPort = false;
    await PrefsUtil.setBool(AppKeys.shareUseCustomPort, false);
    update();
    return true;
  }

  /// 开启自定义端口并写入合法端口。非法时返回 false 且不改持久化开关。
  Future<bool> saveCustomPort(int port) async {
    if (!PortUtil.isValidCustomPort(port)) return false;

    _customPort = port;
    _useCustomPort = true;
    await PrefsUtil.setInt(AppKeys.shareCustomPort, port);
    await PrefsUtil.setBool(AppKeys.shareUseCustomPort, true);
    update();
    return true;
  }

  /// 仅更新已开启自定义模式下的端口值。
  Future<bool> updateCustomPortValue(int port) async {
    if (!_useCustomPort) return false;
    return saveCustomPort(port);
  }

  /// 请求跳转到端口设置。
  void requestNavigateToPortSettings() {
    _navigateToSettings = true;
    _focusPortRequestId++;
    update();
  }

  /// 消费端口设置跳转请求。
  bool consumeNavigateToSettings() {
    if (!_navigateToSettings) return false;
    _navigateToSettings = false;
    return true;
  }

  /// 请求聚焦端口输入框。
  void requestFocusPortField() {
    _focusPortRequestId++;
    update();
  }
}
