import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 左侧导航 Tab。
enum TabSidebarItem {
  home('首页', Icons.dashboard_outlined),
  settings('设置', Icons.settings_outlined),
  config('配置', Icons.tune_outlined),
  links('链接', Icons.link_outlined);

  const TabSidebarItem(this.label, this.icon);

  /// label。
  final String label;

  /// icon。
  final IconData icon;

  /// [sharing] 为 true 时额外展示「链接」。
  static List<TabSidebarItem> visibleTabs({required bool sharing}) {
    return [home, settings, config, if (sharing) links];
  }
}

/// 左侧竖向导航栏。
class TabSidebar extends StatelessWidget {
  const TabSidebar({
    super.key,
    required this.colorValue,
    required this.sharing,
    required this.visibleTabs,
    required this.selected,
    required this.onSelected,
    this.topPadding = 0,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// sharing。
  final bool sharing;

  /// visibleTabs。
  final List<TabSidebarItem> visibleTabs;

  /// 是否选中。
  final TabSidebarItem selected;

  /// onSelected。
  final ValueChanged<TabSidebarItem> onSelected;

  /// topPadding。
  final double topPadding;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: w84,
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: HomePalette.sidebarSurface(sharing: sharing),
        border: Border(
          right: BorderSide(color: HomePalette.sidebarBorder(sharing: sharing)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: h16),
          _Logo(colorValue: colorValue),
          SizedBox(height: h24),
          for (final tab in visibleTabs)
            _NavItem(
              colorValue: colorValue,
              sharing: sharing,
              tab: tab,
              active: tab == selected,
              onTap: () => onSelected(tab),
            ),
          const Spacer(),
          _NavIconButton(
            colorValue: colorValue,
            sharing: sharing,
            icon: Icons.menu,
            onTap: () {},
          ),
          SizedBox(height: h16),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.colorValue});

  /// 颜色配置。
  final ColorValue colorValue;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: w40,
      height: w40,
      decoration: BoxDecoration(
        color: colorValue.homeUploadButtonFill,
        borderRadius: BorderRadius.circular(s12),
      ),
      child: Icon(Icons.bolt, size: f24, color: colorValue.homeUploadIconColor),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.colorValue,
    required this.sharing,
    required this.tab,
    required this.active,
    required this.onTap,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// sharing。
  final bool sharing;

  /// tab。
  final TabSidebarItem tab;

  /// 是否激活。
  final bool active;

  /// 点击回调。
  final VoidCallback onTap;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final activeColor = HomePalette.sidebarForeground(
      sharing: sharing,
      active: true,
    );
    final inactiveColor = HomePalette.sidebarForeground(
      sharing: sharing,
      active: false,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: h6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: h6),
          child: Column(
            children: [
              Container(
                width: w40,
                height: w40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? colorValue.homeUploadButtonFill.withValues(alpha: 0.9)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(s12),
                ),
                child: Icon(
                  tab.icon,
                  size: f20,
                  color: active
                      ? colorValue.homeUploadIconColor
                      : inactiveColor,
                ),
              ),
              SizedBox(height: h4),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: f11,
                  color: active ? activeColor : inactiveColor,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.colorValue,
    required this.sharing,
    required this.icon,
    required this.onTap,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// sharing。
  final bool sharing;

  /// icon。
  final IconData icon;

  /// 点击回调。
  final VoidCallback onTap;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: w48,
        height: w48,
        child: Center(
          child: Icon(
            icon,
            size: f20,
            color: HomePalette.sidebarForeground(
              sharing: sharing,
              active: false,
            ),
          ),
        ),
      ),
    );
  }
}
