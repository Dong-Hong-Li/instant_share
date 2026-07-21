part of 'tab_page.dart';

class _TabPageAppState extends BaseStatePage<TabPage> with TabPageAppMixin {
  String? _lastShownError;

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

    return buildTabBottomNavLayout(
      colorValue: tc,
      home: home,
      topInset: MediaQuery.paddingOf(context).top,
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
