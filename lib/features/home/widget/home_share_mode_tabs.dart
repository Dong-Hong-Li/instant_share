import 'package:flutter/material.dart';
import 'package:instant_share/features/home/data/home_share_mode.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 顶部分享类型切换（带滑块动画）。
class HomeShareModeTabs extends StatelessWidget {
  const HomeShareModeTabs({
    super.key,
    required this.colorValue,
    required this.sharing,
    required this.mode,
    required this.onModeChanged,
  });

  final ColorValue colorValue;
  final bool sharing;
  final HomeShareMode mode;
  final ValueChanged<HomeShareMode> onModeChanged;

  static const _slideDuration = Duration(milliseconds: 240);
  static const _slideCurve = Curves.easeOutCubic;

  static const _tabs = <_TabData>[
    _TabData(HomeShareMode.article, '分享文章', Icons.auto_awesome),
    _TabData(HomeShareMode.file, '分享文件', Icons.insert_drive_file_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final tabWidth = w108;
    final innerHeight = h32;
    final selectedAtRight = mode == HomeShareMode.file;

    return Container(
      padding: EdgeInsets.all(w4),
      decoration: BoxDecoration(
        color: HomePalette.tabTrackBackground(sharing: sharing),
        borderRadius: BorderRadius.circular(s24),
      ),
      child: SizedBox(
        width: tabWidth * 2,
        height: innerHeight,
        child: Stack(
          children: [
            // 滑块：在两个 Tab 之间平滑滑动
            AnimatedAlign(
              duration: _slideDuration,
              curve: _slideCurve,
              alignment: selectedAtRight
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: tabWidth,
                height: innerHeight,
                decoration: BoxDecoration(
                  color: colorValue.homeUploadButtonFill,
                  borderRadius: BorderRadius.circular(s20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: s8,
                      offset: Offset(0, h2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final tab in _tabs)
                  _TabLabel(
                    colorValue: colorValue,
                    sharing: sharing,
                    width: tabWidth,
                    data: tab,
                    selected: tab.mode == mode,
                    onTap: () => onModeChanged(tab.mode),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabData {
  const _TabData(this.mode, this.label, this.icon);

  final HomeShareMode mode;
  final String label;
  final IconData icon;
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.colorValue,
    required this.sharing,
    required this.width,
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final ColorValue colorValue;
  final bool sharing;
  final double width;
  final _TabData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = selected
        ? colorValue.homeUploadIconColor
        : HomePalette.tabUnselectedForeground(sharing: sharing);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              scale: selected ? 1 : 0.92,
              child: Icon(data.icon, size: f15, color: contentColor),
            ),
            SizedBox(width: w6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: f13,
                color: contentColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(data.label),
            ),
          ],
        ),
      ),
    );
  }
}
