part of 'tab_page.dart';

/// App 端 Tab 壳层（[AppPageShell] + 底部 [BottomTabBarView]），与 PC 侧栏分离。
mixin TabPageAppMixin on BaseStatePage<TabPage> {
  TabSidebarItem tab = TabSidebarItem.home;
  bool _handlingPortOccupied = false;

  /// syncTab。
  void syncTab(HomeProvider home) {
    if (!home.isSharing && tab == TabSidebarItem.links) {
      setState(() => tab = TabSidebarItem.home);
    }
  }

  /// maybeHandlePortOccupied。
  void maybeHandlePortOccupied(BuildContext context, HomeProvider home) {
    if (!home.portOccupiedNeedsSettings || _handlingPortOccupied) return;

    _handlingPortOccupied = true;
    home.clearPortOccupiedFlag();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _handlingPortOccupied = false;
        return;
      }
      final goSettings = await showSharePortOccupiedDialog(context);
      if (!mounted) {
        _handlingPortOccupied = false;
        return;
      }
      if (goSettings) {
        setState(() => tab = TabSidebarItem.settings);
        DI.find<SharePortController>().requestFocusPortField();
      }
      _handlingPortOccupied = false;
    });
  }

  /// buildTabGradientShell。
  Widget buildTabGradientShell({
    required HomeProvider home,
    required bool joinedRoom,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: home.isSharing || joinedRoom ? 1.0 : 0.0),
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

  /// buildTab页面。
  Widget buildTabPage(
    TabSidebarItem item,
    ColorValue colorValue,
    HomeProvider home,
    double topInset,
  ) {
    final mutual = ref.watch(mutualShareProvider);
    return switch (item) {
      TabSidebarItem.home => HomeSharePage(
        colorValue: colorValue,
        provider: home,
        mutual: mutual,
        topInset: topInset,
      ),
      TabSidebarItem.settings => SettingPage(
        colorValue: colorValue,
        isSharing: home.isSharing,
      ),
      TabSidebarItem.config => ConfigPage(colorValue: colorValue),
      TabSidebarItem.links => LinkPage(colorValue: colorValue, mutual: mutual),
    };
  }

  TabNavItem _toNavItem(TabSidebarItem item, {int badgeCount = 0}) =>
      TabNavItem(icon: item.icon, label: item.label, badgeCount: badgeCount);

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

    final mutual = ref.watch(mutualShareProvider);
    final linksBadgeCount = mutual.pending.length;
    final activeIndex = visibleTabs.indexOf(tab);
    final navItems = visibleTabs
        .map(
          (item) => _toNavItem(
            item,
            badgeCount: item == TabSidebarItem.links ? linksBadgeCount : 0,
          ),
        )
        .toList(growable: false);
    final pages = visibleTabs
        .map((item) => buildTabPage(item, colorValue, home, topInset))
        .toList(growable: false);

    return buildTabGradientShell(
      home: home,
      joinedRoom: mutual.joinedRoom,
      child: AppPageShell(
        activeIndex: activeIndex,
        onTabSelected: (index) => setState(() => tab = visibleTabs[index]),
        tabItems: navItems,
        pages: pages,
      ),
    );
  }
}
