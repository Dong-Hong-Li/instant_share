part of 'tab_page.dart';

/// App 端 Tab 壳层（[AppPageShell] + 底部 [BottomTabBarView]），与 PC 侧栏分离。
mixin TabPageAppMixin on BaseStatePage<TabPage> {
  TabSidebarItem tab = TabSidebarItem.home;

  void syncTab(HomeProvider home) {
    if (!home.isSharing && tab == TabSidebarItem.links) {
      setState(() => tab = TabSidebarItem.home);
    }
  }

  Widget buildTabGradientShell({
    required HomeProvider home,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: home.isSharing ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      builder: (context, progress, gradientChild) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: HomePalette.lerpBackgroundGradient(progress),
          ),
          child: gradientChild,
        );
      },
      child: child,
    );
  }

  Widget buildTabPage(
    TabSidebarItem item,
    ColorValue colorValue,
    HomeProvider home,
    double topInset,
  ) {
    return switch (item) {
      TabSidebarItem.home => HomeSharePage(
        colorValue: colorValue,
        provider: home,
        topInset: topInset,
      ),
      TabSidebarItem.settings => SettingPage(colorValue: colorValue),
      TabSidebarItem.config => ConfigPage(colorValue: colorValue),
      TabSidebarItem.links => LinkPage(colorValue: colorValue),
    };
  }

  TabNavItem _toNavItem(TabSidebarItem item) =>
      TabNavItem(icon: item.icon, label: item.label);

  /// App 竖屏壳层：[CrossFadeSwitcher] 切换 + shell 底栏导航。
  Widget buildTabBottomNavLayout({
    required ColorValue colorValue,
    required HomeProvider home,
    required double topInset,
  }) {
    final visibleTabs = TabSidebarItem.visibleTabs(sharing: home.isSharing);
    if (!visibleTabs.contains(tab)) {
      setState(() => tab = TabSidebarItem.home);
    }

    final activeIndex = visibleTabs.indexOf(tab);
    final navItems = visibleTabs.map(_toNavItem).toList(growable: false);
    final pages = visibleTabs
        .map((item) => buildTabPage(item, colorValue, home, topInset))
        .toList(growable: false);

    return buildTabGradientShell(
      home: home,
      child: AppPageShell(
        activeIndex: activeIndex,
        onTabSelected: (index) => setState(() => tab = visibleTabs[index]),
        tabItems: navItems,
        pages: pages,
      ),
    );
  }
}
