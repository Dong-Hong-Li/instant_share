import 'package:fluro_router_generate/fluro_router.dart';
import 'package:flutter/material.dart';
import 'package:instant_share/core/config/desktop_window_config.dart';
import 'package:instant_share/core/ui/base/base_state_page.dart';
import 'package:instant_share/core/ui/platform_state_factory.dart';
import 'package:instant_share/features/config/view/config_page.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/features/home/view/home_share_page.dart';
import 'package:instant_share/features/link/view/link_page.dart';
import 'package:instant_share/features/setting/view/setting_page.dart';
import 'package:instant_share/features/tab/widget/tab_sidebar.dart';
import 'package:instant_share/infrastructure/share_server/embedded_server_runtime.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:window_manager/window_manager.dart';

part 'tab_page_mixin.dart';
part 'tab_page_pc.dart';
part 'tab_page_app.dart';

@RouterAnnotation(path: RootPath.home, description: '首页')
class TabPage extends StatefulWidget {
  const TabPage({super.key});

  @override
  State<TabPage> createState() => // ignore: no_logic_in_create_state
      createPlatformState(pc: _TabPagePcState.new, app: _TabPageAppState.new);
}
