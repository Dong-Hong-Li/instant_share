import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 中央主操作按钮的三种形态。
enum HomeActionState {
  /// 未选文件：加号，点击添加
  add,

  /// 已选文件、未分享：开关（灰，待开启）
  shareOff,

  /// 已选文件、分享中：开关（绿，已开启）
  shareOn,
}

/// 中央主操作按钮（参考 VPN 客户端的大圆按钮）。
///
/// 选择文件后由「加号」过渡为更大的「开关」按钮；
/// 开启分享时底色灰→绿、图标黑→白，均带过渡动画。配色取自 [HomePalette]。
class HomeActionButton extends StatelessWidget {
  const HomeActionButton({
    super.key,
    required this.colorValue,
    required this.state,
    required this.enabled,
    required this.onTap,
  });

  final ColorValue colorValue;
  final HomeActionState state;
  final bool enabled;
  final VoidCallback onTap;

  static const Duration _duration = Duration(milliseconds: 320);
  static const Curve _curve = Curves.easeOutCubic;

  bool get _isShareMode => state != HomeActionState.add;
  bool get _isSharing => state == HomeActionState.shareOn;

  @override
  Widget build(BuildContext context) {
    final size = _isShareMode ? w188 : w150;
    final gradient = _isSharing
        ? HomePalette.switchOnGradient
        : HomePalette.switchOffGradient;
    final iconColor = _isSharing
        ? HomePalette.switchIconOn
        : HomePalette.switchIconOff;
    final icon = _isShareMode ? Icons.power_settings_new : Icons.add;

    return _HoverScale(
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: _duration,
            curve: _curve,
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isSharing ? 0.24 : 0.14,
                  ),
                  blurRadius: s24,
                  offset: Offset(0, h8),
                ),
              ],
            ),
            child: Center(
              // 图标颜色随状态平滑过渡（黑 → 白）
              child: TweenAnimationBuilder<Color?>(
                duration: _duration,
                curve: _curve,
                tween: ColorTween(
                  begin: HomePalette.switchIconOff,
                  end: iconColor,
                ),
                builder: (context, color, _) {
                  // 图标字形（加号 ↔ 电源）切换时缩放淡入
                  return AnimatedSwitcher(
                    duration: _duration,
                    switchInCurve: _curve,
                    switchOutCurve: _curve,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      icon,
                      key: ValueKey<IconData>(icon),
                      size: _isShareMode ? f64 : f56,
                      color: color ?? iconColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 鼠标悬停放大。
class _HoverScale extends StatefulWidget {
  const _HoverScale({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedScale(
        scale: _hovered && widget.enabled ? 1.06 : 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
