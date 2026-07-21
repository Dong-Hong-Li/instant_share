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
    this.linksBadgeCount = 0,
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

  /// 「链接」待审批数量；>0 时显示角标。
  final int linksBadgeCount;

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
              badgeCount: tab == TabSidebarItem.links ? linksBadgeCount : 0,
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
    this.badgeCount = 0,
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

  /// 角标数量。
  final int badgeCount;

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
              SizedBox(
                width: w40,
                height: w40,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? colorValue.homeUploadButtonFill.withValues(
                                  alpha: 0.9,
                                )
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
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: _NavBadge(count: badgeCount),
                      ),
                  ],
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

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: BoxConstraints(minWidth: w16, minHeight: w16),
      padding: EdgeInsets.symmetric(horizontal: w4),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: f9,
          height: 1,
          fontWeight: FontWeight.w700,
          color: Colors.white,
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
