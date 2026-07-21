import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/widget/cross_fade_switcher.dart';
import 'package:instant_share/core/ui/widget/shell/bottom_tab_bar_view.dart';
import 'package:instant_share/core/ui/widget/shell/tab_nav_config.dart';

/// App 竖屏壳层：居中限宽内容区 + [CrossFadeSwitcher] 切换 + 底部 [BottomTabBarView]。
class AppPageShell extends StatelessWidget {
  const AppPageShell({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    required this.tabItems,
    required this.pages,
    this.maxContentWidth = 430,
  });

  /// activeIndex。
  final int activeIndex;

  /// onTabSelected。
  final ValueChanged<int> onTabSelected;

  /// tabItems。
  final List<TabNavItem> tabItems;

  /// pages。
  final List<Widget> pages;

  /// maxContentWidth。
  final double maxContentWidth;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    assert(tabItems.length == pages.length, 'tabItems 与 pages 长度须一致');

    final index = tabItems.isEmpty
        ? 0
        : activeIndex.clamp(0, tabItems.length - 1);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final tabOverlay = BottomTabBarView.overlayHeight(context);
    // 键盘覆盖底栏时，仅上推内容区，底栏保持原位。
    final keyboardLift = keyboardInset > 0
        ? (keyboardInset - tabOverlay).clamp(0.0, double.infinity)
        : 0.0;

    return Column(
      children: [
        Expanded(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardLift),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: CrossFadeSwitcher(currentIndex: index, children: pages),
              ),
            ),
          ),
        ),
        BottomTabBarView(
          activeIndex: index,
          maxContentWidth: maxContentWidth,
          tabs: [
            for (var i = 0; i < tabItems.length; i++)
              BottomTabSlot(
                icon: tabItems[i].icon,
                label: tabItems[i].label,
                active: index == i,
                onTap: () => onTabSelected(i),
              ),
          ],
        ),
      ],
    );
  }
}
