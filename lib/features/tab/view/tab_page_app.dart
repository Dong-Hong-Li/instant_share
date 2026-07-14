part of 'tab_page.dart';

class _TabPageAppState extends BaseStatePage<TabPage> with TabPageAppMixin {
  String? _lastShownError;

  @override
  Color? get backgroundColor => Colors.transparent;

  @override
  PreferredSizeWidget? appBar() => null;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  Widget buildPage(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
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
