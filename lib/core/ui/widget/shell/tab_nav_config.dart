import 'package:flutter/material.dart';

/// 底部 Tab 一项的配置（图标 + 文案）。
class TabNavItem {
  const TabNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  /// icon。
  final IconData icon;

  /// label。
  final String label;

  /// 角标数量；>0 时显示。
  final int badgeCount;
}
