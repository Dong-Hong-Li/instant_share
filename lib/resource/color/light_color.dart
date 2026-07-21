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
  /// background。
  @override
  Color get background => const Color(0xFFF5F5F5);

  /// systemNavigationBar颜色。
  @override
  Color get systemNavigationBarColor => Colors.white;

  /// 卡片边框：浅灰
  /// cardBorder颜色。
  @override
  Color get cardBorderColor => const Color(0xFFE0E0E0);

  /// 主文字：深灰黑
  /// textDefault。
  @override
  Color get textDefault => const Color(0xFF212121);

  /// textPrimary。
  @override
  Color get textPrimary => textDefault;

  /// textSecondary。
  @override
  Color get textSecondary => const Color(0xFF616161);

  /// textTertiary。
  @override
  Color get textTertiary => const Color(0xFF9E9E9E);

  /// accentAi。
  @override
  Color get accentAi => const Color(0xFF3949AB);

  /// bottomBarBackdrop。
  @override
  Color get bottomBarBackdrop => const Color(0xCCFFFFFF);

  /// borderSubtle。
  @override
  Color get borderSubtle => const Color(0xFFEEEEEE);

  /// bgElevated。
  @override
  Color get bgElevated => Colors.white;

  /// homeBackgroundGradient。
  @override
  LinearGradient get homeBackgroundGradient => HomePalette.backgroundGradient;

  /// homeTitle颜色。
  @override
  Color get homeTitleColor => HomePalette.title;

  /// homeHint颜色。
  @override
  Color get homeHintColor => HomePalette.hint;

  /// homeUpload按钮Fill。
  @override
  Color get homeUploadButtonFill => HomePalette.uploadButtonFill;

  /// homeUploadIcon颜色。
  @override
  Color get homeUploadIconColor => HomePalette.uploadIcon;
}
