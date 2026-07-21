import 'package:flutter/material.dart';

/// 底部 Tab 一项的配置（图标 + 文案）。
class TabNavItem {
  const TabNavItem({required this.icon, required this.label});

  /// icon。
  final IconData icon;

  /// label。
  final String label;
}
