part of 'tab_page.dart';

/// PC 端 Tab 壳层布局（左侧边栏），App 端见 [TabPageAppMixin]。
mixin TabPagePcMixin on BaseStatePage<TabPage> {
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

  /// buildTabBody。
  Widget buildTabBody(
    ColorValue colorValue,
    HomeProvider home,
    double topInset,
  ) {
    final mutual = ref.watch(mutualShareProvider);
    return switch (tab) {
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

  /// buildTabSidebarLayout。
  Widget buildTabSidebarLayout({
    required ColorValue colorValue,
    required HomeProvider home,
    required double topInset,
    Widget? windowCaption,
  }) {
    final visibleTabs = TabSidebarItem.visibleTabs(sharing: home.isSharing);
    if (!visibleTabs.contains(tab)) {
      setState(() => tab = TabSidebarItem.home);
    }

    // Windows / Linux：侧栏顶到窗口上沿；WindowCaption 只盖右侧内容区，
    // 避免整行 caption 把侧栏顶出一条空白。
    // macOS：无 WindowCaption，两侧共用 topInset 避开交通灯。
    final content = windowCaption == null
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabSidebar(
                colorValue: colorValue,
                sharing: home.isSharing,
                visibleTabs: visibleTabs,
                selected: tab,
                onSelected: (value) => setState(() => tab = value),
                topPadding: topInset,
              ),
              Expanded(child: buildTabBody(colorValue, home, topInset)),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabSidebar(
                colorValue: colorValue,
                sharing: home.isSharing,
                visibleTabs: visibleTabs,
                selected: tab,
                onSelected: (value) => setState(() => tab = value),
                topPadding: 0,
              ),
              Expanded(
                child: Column(
                  children: [
                    windowCaption,
                    Expanded(child: buildTabBody(colorValue, home, topInset)),
                  ],
                ),
              ),
            ],
          );

    return buildTabGradientShell(
      home: home,
      joinedRoom: ref.watch(mutualShareProvider).joinedRoom,
      child: SizedBox.expand(child: content),
    );
  }
}
