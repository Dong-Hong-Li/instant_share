part of 'tab_page.dart';

class _TabPagePcState extends BaseStatePage<TabPage>
    with WindowListener, TabPagePcMixin {
  bool _windowListenerAttached = false;
  String? _lastShownError;

  /// 释放资源。
  @override
  void dispose() {
    if (_windowListenerAttached) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// onWindowClose。
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

  /// background颜色。
  @override
  Color? get backgroundColor => Colors.transparent;

  /// appBar。
  @override
  PreferredSizeWidget? appBar() => null;

  /// resizeToAvoidBottomInset。
  @override
  bool get resizeToAvoidBottomInset => false;

  /// build页面。
  @override
  Widget buildPage(BuildContext context, WidgetRef ref) {
    _ensureWindowListener();
    final home = ref.watch(homeProvider);
    final mutual = ref.watch(mutualShareProvider);
    home.setRoomFileOfferSync(mutual.offerFiles);
    mutual.setOnJoinedRoom(home.publishSelectedFilesToRoom);
    if (home.isSharing) {
      unawaited(mutual.ensureHostAdminListening());
    }
    _maybeShowError(context, home);
    syncTab(home);
    maybeHandlePortOccupied(context, home);

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

  void _maybeShowError(BuildContext context, HomeProvider home) {
    final error = home.errorMessage;
    if (error == null || error == _lastShownError) return;

    _lastShownError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHomeShareSnackBar(context, error);
      home.clearErrorMessage();
      _lastShownError = null;
    });
  }
}
