import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 文章页右上角帮助提示（悬停显示操作流程）。
class HomeArticleHelpHint extends StatelessWidget {
  const HomeArticleHelpHint({super.key, required this.colorValue});

  final ColorValue colorValue;

  static const _steps = [
    '在下方输入框填写内容，回车或点击 + 创建文章',
    '前往「分享文件」页开启分享服务',
    '服务开启后点击文章卡片，切换「已分享」状态',
    '下次启动会自动恢复上次标记为已分享的文章',
  ];

  @override
  Widget build(BuildContext context) {
    final iconColor = colorValue.homeUploadIconColor;

    return Tooltip(
      preferBelow: false,
      verticalOffset: h20,
      waitDuration: const Duration(milliseconds: 200),
      message: _steps.map((step) => '• $step').join('\n'),
      child: Material(
        color: colorValue.homeUploadButtonFill.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(s12),
        child: InkWell(
          onTap: () => _showHelpDialog(context),
          borderRadius: BorderRadius.circular(s12),
          child: SizedBox(
            width: w32,
            height: w32,
            child: Icon(
              Icons.help_outline,
              size: f18,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('文章分享流程'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                if (i > 0) SizedBox(height: h8),
                Text('${i + 1}. ${_steps[i]}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}
