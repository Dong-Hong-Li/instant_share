import 'package:instant_share/core/utils/port/port_util.dart';

/// 设置页端口区块静态文案。
abstract final class SettingPortMessages {
  /// invalidPort。
  static String get invalidPort =>
      '请输入 ${PortUtil.kMinCustomSharePort}–${PortUtil.kMaxCustomSharePort} 的整数端口';

  /// portRangeHint。
  static String get portRangeHint =>
      '${PortUtil.kMinCustomSharePort}–${PortUtil.kMaxCustomSharePort}';

  /// subtitle。
  static const subtitle = '关闭时由系统分配空闲端口；保存后立即切换监听端口';

  /// portAvailable。
  static const portAvailable = '端口可用';

  /// portUnavailable。
  static const portUnavailable = '端口不可用 / 已被占用';

  /// checking。
  static const checking = '检测中…';

  /// check。
  static const check = '检测';

  /// 保存数据。
  static const save = '保存';

  /// portApplied。
  static const portApplied = '端口已生效';

  /// rebindFailed。
  static const rebindFailed = '配置已保存，但服务重绑失败，请稍后重试';

  /// sharingLocked。
  static const sharingLocked = '分享进行中，无法修改端口设置';
}
