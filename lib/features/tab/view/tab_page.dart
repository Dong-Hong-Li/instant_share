import 'dart:async';

import 'package:fluro_router_generate/fluro_router.dart';
import 'package:flutter/material.dart';
import 'package:instant_share/core/config/desktop_window_config.dart';
import 'package:instant_share/core/ui/base/base_state_page.dart';
import 'package:instant_share/core/ui/platform_state_factory.dart';
import 'package:instant_share/features/config/view/config_page.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/features/home/view/home_share_page.dart';
import 'package:instant_share/features/home/widget/home_share_page_shell.dart';
import 'package:instant_share/features/link/view/link_page.dart';
import 'package:instant_share/features/mutual_share/provider/mutual_share_provide.dart';
import 'package:instant_share/features/setting/view/setting_page.dart';
import 'package:instant_share/features/setting/widget/setting_port_section.dart';
import 'package:instant_share/core/controller/share_port_controller.dart';
import 'package:instant_share/core/ui/widget/shell/app_page_shell.dart';
import 'package:instant_share/core/ui/widget/shell/tab_nav_config.dart';
import 'package:instant_share/features/tab/widget/tab_sidebar.dart';
import 'package:instant_share/infrastructure/share_server/share_server_host.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:window_manager/window_manager.dart';

part 'tab_page_mixin.dart';
part 'tab_page_pc.dart';
part 'tab_page_app.dart';
part 'tab_page_app_mixin.dart';

/// Tab页面。
@RouterAnnotation(path: RootPath.home, description: '首页')
class TabPage extends StatefulWidget {
  const TabPage({super.key});

  /// 创建状态对象。
  @override
  State<TabPage> createState() => // ignore: no_logic_in_create_state
      createPlatformState(pc: _TabPagePcState.new, app: _TabPageAppState.new);
}
