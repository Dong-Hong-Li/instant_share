import 'package:fluro_router_generate/fluro_router.dart';
import 'package:flutter/material.dart';
import 'package:instant_share/core/config/desktop_window_config.dart';
import 'package:instant_share/core/ui/base/base_state_page.dart';
import 'package:instant_share/features/config/view/config_page.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/features/home/view/home_article_share_page.dart';
import 'package:instant_share/features/home/view/home_file_share_page.dart';
import 'package:instant_share/features/link/view/link_page.dart';
import 'package:instant_share/features/setting/view/setting_page.dart';
import 'package:instant_share/features/tab/widget/tab_sidebar.dart';
import 'package:instant_share/infrastructure/share_server/embedded_server_runtime.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:window_manager/window_manager.dart';

@RouterAnnotation(path: RootPath.home, description: '首页')
class TabPage extends StatefulWidget {
  const TabPage({super.key});

  @override
  State<TabPage> createState() => _TabPageState();
}

class _TabPageState extends BaseStatePage<TabPage> with WindowListener {
  TabSidebarItem _tab = TabSidebarItem.fileShare;
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
    await EmbeddedServerRuntime.instance.stop();
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

  void _syncTab(HomeProvider home) {
    if (!home.isSharing && _tab == TabSidebarItem.links) {
      _tab = TabSidebarItem.fileShare;
    }
  }

  @override
  Widget buildPage(BuildContext context, WidgetRef ref) {
    _ensureWindowListener();
    final home = ref.watch(homeProvider);
    _syncTab(home);

    final colorValue = tc;
    final useCaption = DesktopWindowConfig.useWindowCaption;
    final topInset = DesktopWindowConfig.topContentInset(
      hasWindowCaption: useCaption,
    );
    final visibleTabs = TabSidebarItem.visibleTabs(sharing: home.isSharing);
    if (!visibleTabs.contains(_tab)) {
      _tab = TabSidebarItem.fileShare;
    }

    final page = TweenAnimationBuilder<double>(
      tween: Tween(end: home.isSharing ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      builder: (context, progress, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: HomePalette.lerpBackgroundGradient(progress),
          ),
          child: child,
        );
      },
      child: SizedBox.expand(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabSidebar(
              colorValue: colorValue,
              sharing: home.isSharing,
              visibleTabs: visibleTabs,
              selected: _tab,
              onSelected: (tab) => setState(() => _tab = tab),
              topPadding: topInset,
            ),
            Expanded(child: _buildBody(colorValue, home, topInset)),
          ],
        ),
      ),
    );

    if (!useCaption) return page;

    return Column(
      children: [
        SizedBox(
          height: kWindowCaptionHeight,
          child: WindowCaption(
            brightness: Brightness.light,
            backgroundColor: Colors.transparent,
          ),
        ),
        Expanded(child: page),
      ],
    );
  }

  Widget _buildBody(ColorValue colorValue, HomeProvider home, double topInset) {
    return switch (_tab) {
      TabSidebarItem.fileShare => HomeFileSharePage(
        colorValue: colorValue,
        provider: home,
        topInset: topInset,
      ),
      TabSidebarItem.articleShare => HomeArticleSharePage(
        colorValue: colorValue,
        provider: home,
        topInset: topInset,
      ),
      TabSidebarItem.settings => SettingPage(colorValue: colorValue),
      TabSidebarItem.config => ConfigPage(colorValue: colorValue),
      TabSidebarItem.links => LinkPage(colorValue: colorValue),
    };
  }
}
