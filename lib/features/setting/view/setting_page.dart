import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/platform_state_factory.dart';
import 'package:instant_share/features/setting/widget/setting_port_section.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';

part 'setting_page_mixin.dart';
part 'setting_page_pc.dart';
part 'setting_page_app.dart';

/// 设置 Tab。
class SettingPage extends StatefulWidget {
  const SettingPage({
    super.key,
    required this.colorValue,
    required this.isSharing,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 是否正在分享。
  final bool isSharing;

  @override
  // ignore: no_logic_in_create_state
  State<SettingPage> createState() => createPlatformState(
    pc: _SettingPagePcState.new,
    app: _SettingPageAppState.new,
  );
}

class _SettingPageContent extends StatelessWidget {
  const _SettingPageContent({
    required this.colorValue,
    required this.isSharing,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 是否正在分享。
  final bool isSharing;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: h24, bottom: h24),
        child: SettingPortSection(colorValue: colorValue, isSharing: isSharing),
      ),
    );
  }
}
