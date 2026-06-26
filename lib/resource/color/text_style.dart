import 'package:flutter/material.dart';

/// 颜色转换为文本样式
extension ColorToTextStyleExtension on Color {
  /// 常规样式
  TextStyle regularStyle(double fontSize, {double? height}) => TextStyle(
        color: this,
        fontWeight: FontWeight.w400,
        fontSize: fontSize,
        height: height ?? 1.0,
      );

  /// 中等样式
  TextStyle mediumStyle(double fontSize, {double? height}) => TextStyle(
        color: this,
        fontWeight: FontWeight.w500,
        fontSize: fontSize,
        height: height ?? 1.0,
      );

  /// 粗体样式
  TextStyle boldStyle(double fontSize, {double? height}) => TextStyle(
        color: this,
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
        height: height ?? 1.0,
      );

  /// 黑体样式
  TextStyle blackStyle(double fontSize, {double? height}) => TextStyle(
        color: this,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        height: height ?? 1.0,
      );
}
