import 'package:flutter/material.dart';

/// 首页（桌面主界面）专用色板，亮/暗主题共用同一套视觉。
abstract final class HomePalette {
  /// 上亮下暗、整体偏亮的冷灰渐变（贴近 EZ Share）
  static const Color gradientTop = Color(0xFFA8B0BC);
  static const Color gradientMiddle = Color(0xFF868F9C);
  static const Color gradientBottom = Color(0xFF5A6370);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientTop, gradientMiddle, gradientBottom],
    stops: [0.0, 0.42, 1.0],
  );

  /// 分享中（天青 / 青蓝系）：上天青 → 下淡青蓝
  static const Color sharingGradientTop = Color(0xFF52AEE6);
  static const Color sharingGradientMiddle = Color(0xFF7EC4EF);
  static const Color sharingGradientBottom = Color(0xFFC2E4F8);

  /// 分享态辅助文字（浅青白，预留）。
  static const Color sharingSecondaryText = Color(0xFFE8F4FC);

  static const LinearGradient sharingBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [sharingGradientTop, sharingGradientMiddle, sharingGradientBottom],
    stops: [0.0, 0.45, 1.0],
  );

  /// [t] 为 0~1：0 idle 灰渐变，1 分享中天青→淡青蓝渐变。
  static LinearGradient lerpBackgroundGradient(double t) {
    final progress = t.clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(gradientTop, sharingGradientTop, progress)!,
        Color.lerp(gradientMiddle, sharingGradientMiddle, progress)!,
        Color.lerp(gradientBottom, sharingGradientBottom, progress)!,
      ],
      stops: const [0.0, 0.42, 1.0],
    );
  }

  static const Color title = Color(0xFFFFFFFF);
  static const Color hint = Color(0xE6FFFFFF);
  static const Color uploadButtonFill = Color(0xFFFFFFFF);
  static const Color uploadIcon = Color(0xFF4A5260);

  // ---- 中央开关按钮：灰（待开启）→ 绿（已开启） ----

  /// 开关待开启：灰色渐变
  static const LinearGradient switchOffGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFC6CDD8), Color(0xFF9AA4B2)],
  );

  /// 开关已开启：绿色渐变（参考 VPN 连接按钮）
  static const LinearGradient switchOnGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF63D480), Color(0xFF34B45B)],
  );

  /// 开关图标：待开启（深）/ 已开启（白）
  static const Color switchIconOff = Color(0xFF4A5260);
  static const Color switchIconOn = Color(0xFFFFFFFF);

  /// 分享中状态/倒计时等前景色。
  static Color statusText({required bool sharing}) => sharing ? title : title;

  /// 分享倒计时文字。
  static Color countdownText({required bool sharing}) =>
      sharing ? title : title;

  /// 侧边栏半透明底（青蓝衬底）。
  static Color sidebarSurface({required bool sharing}) {
    return sharing
        ? const Color(0xFF2890C4).withValues(alpha: 0.28)
        : title.withValues(alpha: 0.12);
  }

  /// 侧边栏分隔线。
  static Color sidebarBorder({required bool sharing}) {
    return sharing
        ? title.withValues(alpha: 0.18)
        : title.withValues(alpha: 0.12);
  }

  /// 侧边栏标签/图标。
  static Color sidebarForeground({
    required bool sharing,
    required bool active,
  }) {
    if (sharing) {
      return active ? title : title.withValues(alpha: 0.72);
    }
    return active ? title : title.withValues(alpha: 0.6);
  }

  /// 顶部分享类型 Tab 未选中项（青蓝底上的深青灰字）。
  static Color tabUnselectedForeground({required bool sharing}) {
    return sharing ? const Color(0xFF1E5F7A) : title.withValues(alpha: 0.85);
  }

  /// 顶部分享类型 Tab 胶囊底。
  static Color tabTrackBackground({required bool sharing}) {
    return sharing
        ? const Color(0xFF2890C4).withValues(alpha: 0.2)
        : title.withValues(alpha: 0.14);
  }

  // ---- 文章卡片：已选中（待分享）/ 已分享 ----

  /// 已选中、服务未开：淡蓝底 + 蓝字（与分享绿区分）。
  static const LinearGradient articleSelectedGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE6EEFC), Color(0xFFC8D8F5)],
  );

  static const Color articleSelectedBorder = Color(0xFF6B93E0);
  static const Color articleSelectedForeground = Color(0xFF2E4A82);
}
