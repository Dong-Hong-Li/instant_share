import 'package:flutter/material.dart';

/// 主题色板抽象：亮色/暗色各实现一套，避免暗色下误用亮色导致不可见。
/// 子类必须实现所有 getter，保证亮暗主题下都有正确对比度。
abstract class ColorValue {
  /// 页面背景色（如 Scaffold）
  Color get background;

  /// 系统导航栏背景色
  Color get systemNavigationBarColor;

  /// 卡片边框色
  Color get cardBorderColor;

  /// 正文/标题等默认文字色
  Color get textDefault;

  /// 主标题/高强调正文（通常与 [textDefault] 同级对比度）
  Color get textPrimary;

  /// 次要说明文字
  Color get textSecondary;

  /// 弱提示、未选中 Tab 图标等
  Color get textTertiary;

  /// 强调色（Tab 激活、点缀）
  Color get accentAi;

  /// 底栏毛玻璃衬底
  Color get bottomBarBackdrop;

  /// 轻描边/分割线（卡片、顶栏分割等）
  Color get borderSubtle;

  /// 浮起的表面色（卡片、浅色块）
  Color get bgElevated;

  /// 首页竖向渐变背景（桌面端主界面）
  LinearGradient get homeBackgroundGradient;

  /// 首页渐变背景上的标题色
  Color get homeTitleColor;

  /// 首页渐变背景上的提示文字色
  Color get homeHintColor;

  /// 首页上传按钮圆形底色
  Color get homeUploadButtonFill;

  /// 首页上传按钮图标色
  Color get homeUploadIconColor;
}
