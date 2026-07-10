part of 'tab_page.dart';

class _TabPagePcState extends BaseStatePage<TabPage>
    with WindowListener, TabPagePcMixin {
  bool _windowListenerAttached = false;

  @override
  void dispose() {
    if (_windowListenerAttached) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    try {
      await ref.read(homeProvider).stopSharingIfNeeded();
    } catch (_) {}
    await ShareServerHost.instance.stop();
    await windowManager.destroy();
  }

  void _ensureWindowListener() {
    if (_windowListenerAttached || !DesktopWindowConfig.isDesktop) return;
    _windowListenerAttached = true;
    windowManager.addListener(this);
  }

  @override
  Color? get backgroundColor => Colors.transparent;

  @override
  PreferredSizeWidget? appBar() => null;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  Widget buildPage(BuildContext context, WidgetRef ref) {
    _ensureWindowListener();
    final home = ref.watch(homeProvider);
    syncTab(home);

    final colorValue = tc;
    // macOS：系统交通灯 + 隐藏标题栏；Windows / Linux：自定义 WindowCaption。
    final useCaption = DesktopWindowConfig.useWindowCaption;
    final topInset = DesktopWindowConfig.topContentInset(
      hasWindowCaption: useCaption,
    );

    return buildTabSidebarLayout(
      colorValue: colorValue,
      home: home,
      topInset: topInset,
      windowCaption: useCaption
          ? const SizedBox(
              height: kWindowCaptionHeight,
              child: WindowCaption(
                brightness: Brightness.light,
                backgroundColor: Colors.transparent,
              ),
            )
          : null,
    );
  }
}
