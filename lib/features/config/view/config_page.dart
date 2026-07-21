import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/platform_state_factory.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

part 'config_page_mixin.dart';
part 'config_page_pc.dart';
part 'config_page_app.dart';

/// 配置 Tab（占位）。
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key, required this.colorValue});

  /// 颜色配置。
  final ColorValue colorValue;

  @override
  // ignore: no_logic_in_create_state
  State<ConfigPage> createState() => createPlatformState(
    pc: _ConfigPagePcState.new,
    app: _ConfigPageAppState.new,
  );
}

class _ConfigPageContent extends StatelessWidget {
  const _ConfigPageContent({required this.colorValue});

  /// 颜色配置。
  final ColorValue colorValue;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: w24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '配置',
              style: TextStyle(
                fontSize: f18,
                fontWeight: FontWeight.w600,
                color: colorValue.homeTitleColor,
              ),
            ),
            SizedBox(height: h8),
            Text(
              '功能规划中',
              style: TextStyle(fontSize: f14, color: colorValue.homeHintColor),
            ),
          ],
        ),
      ),
    );
  }
}
