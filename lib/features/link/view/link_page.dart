import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 链接 Tab（仅分享中展示，占位）。
class LinkPage extends StatelessWidget {
  const LinkPage({super.key, required this.colorValue});

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
              '链接',
              style: TextStyle(
                fontSize: f18,
                fontWeight: FontWeight.w600,
                color: colorValue.homeTitleColor,
              ),
            ),
            SizedBox(height: h8),
            Text(
              '分享链接与二维码（规划中）',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: f14, color: colorValue.homeHintColor),
            ),
          ],
        ),
      ),
    );
  }
}
