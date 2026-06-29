import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';

/// 右上角问号：悬停展示分享地址，点击复制（多地址时弹出菜单选择）。
class HomeServerUrlHint extends StatelessWidget {
  const HomeServerUrlHint({
    super.key,
    required this.shareUrl,
    required this.alternateShareUrls,
    required this.onCopyUrl,
    this.sharing = false,
  });

  final String? shareUrl;
  final List<String> alternateShareUrls;
  final Future<void> Function(String url) onCopyUrl;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final primary = _trimUrl(shareUrl);
    if (primary == null) {
      return const SizedBox.shrink();
    }

    final alternates = alternateShareUrls
        .map(_trimUrl)
        .whereType<String>()
        .toList(growable: false);

    final iconColor = HomePalette.statusText(
      sharing: sharing,
    ).withValues(alpha: 0.8);

    return Tooltip(
      message: _buildTooltipMessage(primary: primary, alternates: alternates),
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              _handleTap(context, primary: primary, alternates: alternates),
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

  Future<void> _handleTap(
    BuildContext context, {
    required String primary,
    required List<String> alternates,
  }) async {
    if (alternates.isEmpty) {
      await onCopyUrl(primary);
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !context.mounted) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem<String>(
          value: primary,
          child: Text(
            '分享地址：$primary',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ...alternates.map(
          (url) => PopupMenuItem<String>(
            value: url,
            child: Text(
              '其他可用地址：$url',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );

    if (selected != null) {
      await onCopyUrl(selected);
    }
  }

  String _buildTooltipMessage({
    required String primary,
    required List<String> alternates,
  }) {
    final lines = <String>['分享地址：$primary'];

    for (final url in alternates) {
      lines.add('其他可用地址：$url');
    }

    lines.add(alternates.isEmpty ? '点击图标复制分享地址' : '点击图标选择并复制');
    return lines.join('\n');
  }

  String? _trimUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
