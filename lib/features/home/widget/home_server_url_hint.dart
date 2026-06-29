import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';

/// 右上角问号：悬停展示服务地址，点击复制分享地址。
class HomeServerUrlHint extends StatelessWidget {
  const HomeServerUrlHint({
    super.key,
    required this.httpBase,
    required this.shareUrl,
    required this.onCopyTap,
    this.sharing = false,
  });

  final String? httpBase;
  final String? shareUrl;
  final VoidCallback onCopyTap;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final localBase = _trimUrl(httpBase);
    final lanShare = _trimUrl(shareUrl);
    if (localBase == null && lanShare == null) {
      return const SizedBox.shrink();
    }

    final iconColor = HomePalette.statusText(sharing: sharing).withValues(
      alpha: 0.8,
    );

    return Tooltip(
      message: _buildTooltipMessage(localBase: localBase, lanShare: lanShare),
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onCopyTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(s6),
            child: Icon(
              Icons.help_outline_rounded,
              size: f24,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  String _buildTooltipMessage({
    required String? localBase,
    required String? lanShare,
  }) {
    final lines = <String>[];

    if (lanShare != null) {
      lines.add('分享地址：$lanShare');
    }
    if (localBase != null && localBase != lanShare) {
      lines.add('本地服务：$localBase');
    }
    lines.add('点击图标复制分享地址');

    return lines.join('\n');
  }

  String? _trimUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
