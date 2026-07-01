import 'package:instant_share/resource/color/color_value.dart';
import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/widget/shell/tab_scroll_insets.dart';

/// 各 Tab 页共用占位布局（后续可换为真实业务页）。
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({
    super.key,
    required this.title,
    required this.colorValue,
  });

  final String title;
  final ColorValue colorValue;

  static const double _contentPadding = 24;

  @override
  Widget build(BuildContext context) {
    final c = colorValue;
    return ListView(
      padding: TabScrollInsets.merge(
        context,
        left: _contentPadding,
        top: _contentPadding,
        right: _contentPadding,
        bottomExtra: _contentPadding,
      ),
      children: [
        Text(
          title,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '路由占位内容，可替换为业务模块。',
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Text(
            '卡片区域示例（bgElevated + borderSubtle）',
            style: TextStyle(color: c.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
