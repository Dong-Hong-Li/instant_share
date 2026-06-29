import 'package:flutter/material.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/features/home/widget/home_action_button.dart';
import 'package:instant_share/features/home/widget/home_file_list.dart';
import 'package:instant_share/features/home/widget/home_server_url_hint.dart';
import 'package:instant_share/features/home/widget/home_share_countdown.dart';
import 'package:instant_share/features/home/widget/home_share_link_actions.dart';
import 'package:instant_share/features/home/widget/home_share_page_shell.dart';
import 'package:instant_share/features/home/widget/home_share_qr_dialog.dart';
import 'package:instant_share/features/home/widget/home_summary_card.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 分享文件页。
class HomeFileSharePage extends StatelessWidget {
  const HomeFileSharePage({
    super.key,
    required this.colorValue,
    required this.provider,
    required this.topInset,
  });

  final ColorValue colorValue;
  final HomeProvider provider;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return HomeSharePageShell(
      topInset: topInset,
      topRight: provider.hasServerInfo
          ? HomeServerUrlHint(
              shareUrl: provider.serverShareUrl,
              alternateShareUrls: provider.alternateShareUrls,
              sharing: provider.isSharing,
              onCopyUrl: (url) => _copyServerUrl(context, url),
            )
          : null,
      body: Column(
        children: [
          SizedBox(height: topInset + h20),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(w24, 0, w24, h20),
              child: _FileShareBody(colorValue: colorValue, provider: provider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyServerUrl(BuildContext context, String url) async {
    final copied = await provider.copyShareUrlToClipboard(url);
    if (!context.mounted) return;
    showHomeShareSnackBar(context, copied ? '分享地址已复制' : '暂无分享地址');
  }
}

class _FileShareBody extends StatelessWidget {
  const _FileShareBody({required this.colorValue, required this.provider});

  final ColorValue colorValue;
  final HomeProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasFiles = provider.hasFiles;
    final isSharing = provider.isSharing;

    final actionState = isSharing
        ? HomeActionState.shareOn
        : HomeActionState.shareOff;

    final statusText = isSharing ? '正在分享…点击关闭' : '点击开关开启分享';

    final shareControls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HomeActionButton(
          colorValue: colorValue,
          state: actionState,
          enabled: !provider.isPicking && !provider.isShareBusy,
          onTap: provider.toggleSharing,
        ),
        SizedBox(height: h16),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: f16,
            fontWeight: FontWeight.w600,
            color: HomePalette.statusText(sharing: isSharing),
          ),
        ),
        SizedBox(height: h8),
        HomeShareCountdown(colorValue: colorValue, active: isSharing),
        if (isSharing) ...[
          SizedBox(height: h16),
          HomeShareLinkActions(
            colorValue: colorValue,
            onQrTap: () => _showQrCode(context),
            onCopyTap: () => _copyShareUrl(context),
          ),
        ],
      ],
    );

    final summaryCard = HomeSummaryCard(
      colorValue: colorValue,
      fileCount: provider.fileCount,
      totalSize: provider.totalFileSize,
      onAddTap: provider.pickFiles,
      onClearTap: provider.clearFiles,
    );

    return Column(
      children: [
        SizedBox(height: h8),
        if (hasFiles) ...[
          shareControls,
          SizedBox(height: h16),
          Expanded(
            child: Column(
              children: [
                summaryCard,
                SizedBox(height: h12),
                Expanded(
                  child: HomeFileList(
                    colorValue: colorValue,
                    files: provider.selectedFiles,
                    onRemove: provider.removeFile,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                shareControls,
                SizedBox(height: h12),
              ],
            ),
          ),
          summaryCard,
        ],
      ],
    );
  }

  void _showQrCode(BuildContext context) {
    final url = provider.shareUrl;
    if (url == null || url.isEmpty) {
      showHomeShareSnackBar(context, '暂无分享地址');
      return;
    }
    showHomeShareQrDialog(context, shareUrl: url, colorValue: colorValue);
  }

  Future<void> _copyShareUrl(BuildContext context) async {
    final copied = await provider.copyShareUrl();
    if (!context.mounted) return;
    showHomeShareSnackBar(context, copied ? '分享地址已复制' : '暂无分享地址');
  }
}
