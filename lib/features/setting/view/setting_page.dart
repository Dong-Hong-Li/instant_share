import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/platform_state_factory.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

part 'setting_page_mixin.dart';
part 'setting_page_pc.dart';
part 'setting_page_app.dart';

/// 设置 Tab（占位）。
class SettingPage extends StatefulWidget {
  const SettingPage({super.key, required this.colorValue});

  final ColorValue colorValue;

  @override
  // ignore: no_logic_in_create_state
  State<SettingPage> createState() => createPlatformState(
    pc: _SettingPagePcState.new,
    app: _SettingPageAppState.new,
  );
}

class _SettingPageContent extends StatelessWidget {
  const _SettingPageContent({required this.colorValue});

  final ColorValue colorValue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: w24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '设置',
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
