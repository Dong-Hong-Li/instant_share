part of 'tab_page.dart';

class _TabPageAppState extends BaseStatePage<TabPage> with TabPageMixin {
  @override
  Color? get backgroundColor => Colors.transparent;

  @override
  PreferredSizeWidget? appBar() => null;

  @override
  bool get resizeToAvoidBottomInset => false;

  @override
  Widget buildPage(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    syncTab(home);

    return buildTabSidebarLayout(
      colorValue: tc,
      home: home,
      topInset: MediaQuery.paddingOf(context).top,
    );
  }
}
