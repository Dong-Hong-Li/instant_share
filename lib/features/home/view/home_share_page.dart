import 'dart:io';

import 'package:flutter/material.dart';
import 'package:instant_share/core/config/desktop_window_config.dart';
import 'package:instant_share/core/ui/widget/cross_fade_switcher.dart';
import 'package:instant_share/features/home/data/home_share_mode.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/features/home/widget/home_action_button.dart';
import 'package:instant_share/features/home/widget/home_file_list.dart';
import 'package:instant_share/features/home/widget/home_server_url_hint.dart';
import 'package:instant_share/features/home/widget/home_share_countdown.dart';
import 'package:instant_share/features/home/widget/home_share_link_actions.dart';
import 'package:instant_share/features/home/widget/home_share_mode_tabs.dart';
import 'package:instant_share/features/home/widget/home_share_qr_dialog.dart';
import 'package:instant_share/features/home/widget/home_summary_card.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';
import 'package:window_manager/window_manager.dart';

void _showHomeSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// 首页 Tab：文件 / 文章分享。
class HomeSharePage extends StatelessWidget {
  const HomeSharePage({
    super.key,
    required this.colorValue,
    required this.provider,
    required this.topInset,
  });

  final ColorValue colorValue;
  final HomeProvider provider;
  final double topInset;

  bool get _useMacOsTitleBarInset =>
      DesktopWindowConfig.usesHiddenTitleBar && Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final isFileMode = provider.shareMode == HomeShareMode.file;

    final content = Stack(
      children: [
        Column(
          children: [
            SizedBox(height: topInset),
            HomeShareModeTabs(
              colorValue: colorValue,
              sharing: provider.isSharing,
              mode: provider.shareMode,
              onModeChanged: provider.setShareMode,
            ),
            SizedBox(height: h20),
            Expanded(
              child: CrossFadeSwitcher(
                currentIndex: isFileMode ? 0 : 1,
                children: [
                  _FileModeBody(colorValue: colorValue, provider: provider),
                  _ArticlePlaceholder(colorValue: colorValue),
                ],
              ),
            ),
          ],
        ),
        if (isFileMode && provider.hasServerInfo)
          Positioned(
            top: topInset + h12,
            right: w24,
            child: HomeServerUrlHint(
              shareUrl: provider.serverShareUrl,
              alternateShareUrls: provider.alternateShareUrls,
              sharing: provider.isSharing,
              onCopyUrl: (url) => _copyServerUrl(context, url),
            ),
          ),
      ],
    );

    if (!_useMacOsTitleBarInset) return content;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + h32,
          child: const DragToMoveArea(child: SizedBox.expand()),
        ),
        content,
      ],
    );
  }

  Future<void> _copyServerUrl(BuildContext context, String url) async {
    final copied = await provider.copyShareUrlToClipboard(url);
    if (!context.mounted) return;
    _showHomeSnackBar(context, copied ? '分享地址已复制' : '暂无分享地址');
  }
}

class _FileModeBody extends StatelessWidget {
  const _FileModeBody({required this.colorValue, required this.provider});

  final ColorValue colorValue;
  final HomeProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasFiles = provider.hasFiles;
    final isSharing = provider.isSharing;

    final actionState = !hasFiles
        ? HomeActionState.add
        : isSharing
        ? HomeActionState.shareOn
        : HomeActionState.shareOff;

    final statusText = !hasFiles
        ? '点击添加要分享的文件'
        : isSharing
        ? '正在分享…点击关闭'
        : '点击开关开始分享';

    return Padding(
      padding: EdgeInsets.fromLTRB(w24, 0, w24, h20),
      child: Column(
        children: [
          SizedBox(height: h8),
          HomeActionButton(
            colorValue: colorValue,
            state: actionState,
            enabled: !provider.isPicking && !provider.isShareBusy,
            onTap: hasFiles ? provider.toggleSharing : provider.pickFiles,
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
          SizedBox(height: h16),
          if (hasFiles) ...[
            HomeSummaryCard(
              colorValue: colorValue,
              fileCount: provider.fileCount,
              totalSize: provider.totalFileSize,
              onAddTap: provider.pickFiles,
              onClearTap: provider.clearFiles,
            ),
            SizedBox(height: h12),
            Expanded(
              child: HomeFileList(
                colorValue: colorValue,
                files: provider.selectedFiles,
                onRemove: provider.removeFile,
              ),
            ),
          ] else ...[
            const Expanded(child: SizedBox.shrink()),
            HomeSummaryCard(
              colorValue: colorValue,
              fileCount: provider.fileCount,
              totalSize: provider.totalFileSize,
              onAddTap: provider.pickFiles,
              onClearTap: provider.clearFiles,
            ),
          ],
        ],
      ),
    );
  }

  void _showQrCode(BuildContext context) {
    final url = provider.shareUrl;
    if (url == null || url.isEmpty) {
      _showHomeSnackBar(context, '暂无分享地址');
      return;
    }
    showHomeShareQrDialog(context, shareUrl: url, colorValue: colorValue);
  }

  Future<void> _copyShareUrl(BuildContext context) async {
    final copied = await provider.copyShareUrl();
    if (!context.mounted) return;
    _showHomeSnackBar(context, copied ? '分享地址已复制' : '暂无分享地址');
  }
}

class _ArticlePlaceholder extends StatelessWidget {
  const _ArticlePlaceholder({required this.colorValue});

  final ColorValue colorValue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: w24),
        child: Text(
          '分享文章功能规划中',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: f14, color: colorValue.homeHintColor),
        ),
      ),
    );
  }
}
