import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';

/// 暗色主题色板：深底 + 浅字，对比清晰
class DarkColor extends ColorValue {
  static final DarkColor _instance = DarkColor._();
  factory DarkColor() => _instance;
  DarkColor._();
  static DarkColor get instance => _instance;

  /// Material 标准暗色背景
  @override
  Color get background => const Color(0xFF121212);

  @override
  Color get systemNavigationBarColor => Colors.black;

  /// 卡片边框：深灰，在暗底上可见
  @override
  Color get cardBorderColor => const Color(0xFF3D3D3D);

  /// 主文字：浅灰白
  @override
  Color get textDefault => const Color(0xFFE0E0E0);

  @override
  Color get textPrimary => textDefault;

  @override
  Color get textSecondary => const Color(0xFFBDBDBD);

  @override
  Color get textTertiary => const Color(0xFF888888);

  @override
  Color get accentAi => const Color(0xFF8B9DFF);

  @override
  Color get bottomBarBackdrop => const Color(0xCC121212);

  @override
  Color get borderSubtle => const Color(0xFF333333);

  @override
  Color get bgElevated => const Color(0xFF1E1E1E);

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
