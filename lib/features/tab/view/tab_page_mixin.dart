part of 'tab_page.dart';

mixin TabPageMixin on BaseStatePage<TabPage> {
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

  Widget buildTabBody(ColorValue colorValue, HomeProvider home, double topInset) {
    return switch (tab) {
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

  Widget buildTabSidebarLayout({
    required ColorValue colorValue,
    required HomeProvider home,
    required double topInset,
  }) {
    final visibleTabs = TabSidebarItem.visibleTabs(sharing: home.isSharing);
    if (!visibleTabs.contains(tab)) {
      setState(() => tab = TabSidebarItem.home);
    }

    return buildTabGradientShell(
      home: home,
      child: SizedBox.expand(
        child: Row(
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
        ),
      ),
    );
  }
}
