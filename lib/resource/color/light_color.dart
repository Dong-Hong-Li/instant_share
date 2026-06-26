import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';

/// 亮色主题色板：浅底 + 深字，对比清晰
class LightColor extends ColorValue {
  static final LightColor _instance = LightColor._();
  factory LightColor() => _instance;
  LightColor._();
  static LightColor get instance => _instance;

  /// 浅灰背景，与纯白区分
  @override
  Color get background => const Color(0xFFF5F5F5);

  @override
  Color get systemNavigationBarColor => Colors.white;

  /// 卡片边框：浅灰
  @override
  Color get cardBorderColor => const Color(0xFFE0E0E0);

  /// 主文字：深灰黑
  @override
  Color get textDefault => const Color(0xFF212121);

  @override
  Color get textPrimary => textDefault;

  @override
  Color get textSecondary => const Color(0xFF616161);

  @override
  Color get textTertiary => const Color(0xFF9E9E9E);

  @override
  Color get accentAi => const Color(0xFF3949AB);

  @override
  Color get bottomBarBackdrop => const Color(0xCCFFFFFF);

  @override
  Color get borderSubtle => const Color(0xFFEEEEEE);

  @override
  Color get bgElevated => Colors.white;

  @override
  LinearGradient get homeBackgroundGradient => HomePalette.backgroundGradient;

  @override
  Color get homeTitleColor => HomePalette.title;

  @override
  Color get homeHintColor => HomePalette.hint;

  @override
  Color get homeUploadButtonFill => HomePalette.uploadButtonFill;

  @override
  Color get homeUploadIconColor => HomePalette.uploadIcon;
}
