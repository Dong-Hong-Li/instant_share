import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/core/config/desktop_window_config.dart';
import 'package:instant_share/core/ui/platform_state_factory.dart';
import 'package:instant_share/core/ui/widget/cross_fade_switcher.dart';
import 'package:instant_share/features/home/data/home_share_mode.dart';
import 'package:instant_share/features/home/data/home_article_input_scroll.dart';
import 'package:instant_share/features/home/data/home_article_limits.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/features/home/widget/home_action_button.dart';
import 'package:instant_share/features/home/widget/home_article_card.dart';
import 'package:instant_share/features/home/widget/home_article_create_input.dart';
import 'package:instant_share/features/home/widget/home_article_help_hint.dart';
import 'package:instant_share/features/home/widget/home_file_list.dart';
import 'package:instant_share/features/home/widget/home_server_url_hint.dart';
import 'package:instant_share/features/home/widget/home_share_countdown.dart';
import 'package:instant_share/features/home/widget/home_share_link_actions.dart';
import 'package:instant_share/features/home/widget/home_share_mode_tabs.dart';
import 'package:instant_share/features/home/widget/home_share_page_shell.dart';
import 'package:instant_share/features/home/widget/home_share_qr_dialog.dart';
import 'package:instant_share/features/home/widget/home_summary_card.dart';
import 'package:instant_share/features/mutual_share/provider/mutual_share_provide.dart';
import 'package:instant_share/features/mutual_share/widget/connect_peer_button.dart';
import 'package:instant_share/features/mutual_share/widget/connect_peer_dialog.dart';
import 'package:instant_share/features/mutual_share/widget/pairing_waiting_overlay.dart';
import 'package:instant_share/features/mutual_share/widget/room_catalog_list.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';
import 'package:window_manager/window_manager.dart';

part 'home_share_page_pc.dart';
part 'home_share_page_app.dart';

/// 首页：顶部分享类型滑块 + 文件 / 文章内容切换。
class HomeSharePage extends StatefulWidget {
  const HomeSharePage({
    super.key,
    required this.colorValue,
    required this.provider,
    required this.mutual,
    required this.topInset,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 状态提供者。
  final HomeProvider provider;

  /// mutual。
  final MutualShareProvider mutual;

  /// topInset。
  final double topInset;

  @override
  // ignore: no_logic_in_create_state
  State<HomeSharePage> createState() => createPlatformState(
    pc: _HomeSharePagePcState.new,
    app: _HomeSharePageAppState.new,
  );
}

class _JoinedRoomBody extends StatelessWidget {
  const _JoinedRoomBody({
    required this.colorValue,
    required this.provider,
    required this.mutual,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 状态提供者。
  final HomeProvider provider;

  /// mutual。
  final MutualShareProvider mutual;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(w24, 0, w24, h16),
      child: Column(
        children: [
          Expanded(
            child: RoomCatalogList(
              colorValue: colorValue,
              entries: mutual.catalog,
            ),
          ),
          SizedBox(height: h12),
          HomeSummaryCard(
            colorValue: colorValue,
            fileCount: provider.fileCount,
            totalSize: provider.totalFileSize,
            onAddTap: provider.pickFiles,
            onClearTap: provider.clearFiles,
          ),
          if (provider.hasFiles) ...[
            SizedBox(height: h10),
            SizedBox(
              height: h120,
              child: HomeFileList(
                colorValue: colorValue,
                files: provider.selectedFiles,
                onRemove: provider.removeFile,
              ),
            ),
          ],
          SizedBox(height: h8),
          TextButton(onPressed: mutual.leaveRoom, child: const Text('退出房间')),
        ],
      ),
    );
  }
}

class _FileModeBody extends StatelessWidget {
  const _FileModeBody({required this.colorValue, required this.provider});

  /// 颜色配置。
  final ColorValue colorValue;

  /// 状态提供者。
  final HomeProvider provider;

  /// 构建界面。
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

    // 房间目录占用下方高度时，分享控件可能高于可用区域；顶部限高可滚，避免溢出。
    return Padding(
      padding: EdgeInsets.fromLTRB(w24, 0, w24, h20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // summary + 间距 + 列表最小可视高度
          final reservedBottom = hasFiles ? (h16 + 64 + h12 + 72) : 64;
          final topMaxHeight = (constraints.maxHeight - reservedBottom).clamp(
            0.0,
            constraints.maxHeight,
          );

          return Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: topMaxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: h8),
                      shareControls,
                    ],
                  ),
                ),
              ),
              if (hasFiles) ...[
                SizedBox(height: h16),
                summaryCard,
                SizedBox(height: h12),
                Expanded(
                  child: HomeFileList(
                    colorValue: colorValue,
                    files: provider.selectedFiles,
                    onRemove: provider.removeFile,
                  ),
                ),
              ] else ...[
                const Spacer(),
                summaryCard,
              ],
            ],
          );
        },
      ),
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

class _ArticleShareBody extends StatefulWidget {
  const _ArticleShareBody({required this.colorValue, required this.provider});

  /// 颜色配置。
  final ColorValue colorValue;

  /// 状态提供者。
  final HomeProvider provider;

  /// 创建状态对象。
  @override
  State<_ArticleShareBody> createState() => _ArticleShareBodyState();
}

class _ArticleShareBodyState extends State<_ArticleShareBody> {
  late final TextEditingController _titleController;

  late final TextEditingController _contentController;

  late final FocusNode _contentFocusNode;

  late final ScrollController _contentScrollController;

  /// 状态提供者。
  HomeProvider get provider => widget.provider;

  /// 颜色配置。
  ColorValue get colorValue => widget.colorValue;

  /// 初始化状态。
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _contentFocusNode = FocusNode(onKeyEvent: _handleContentKey);
    _contentScrollController = ScrollController();
  }

  KeyEventResult _handleContentKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;

    if (HomeArticleInputShortcuts.shouldInsertNewlineOnEnter()) {
      _insertContentNewline();
      return KeyEventResult.handled;
    }

    _onCreateArticle();
    return KeyEventResult.handled;
  }

  void _insertContentNewline() {
    final controller = _contentController;
    final value = controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, '\n');
    controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
      composing: TextRange.empty,
    );
    HomeArticleInputScroll.scrollToCaret(
      controller: controller,
      scrollController: _contentScrollController,
    );
  }

  /// 释放资源。
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final articles = provider.articles;
    final isSharing = provider.isSharing;

    return Padding(
      padding: EdgeInsets.fromLTRB(w24, 0, w24, h20),
      child: Column(
        children: [
          SizedBox(height: h8),
          Expanded(
            child: articles.isEmpty
                ? Center(
                    child: Text(
                      isSharing ? '创建文章后点击卡片即可分享' : '暂无文章',
                      style: TextStyle(
                        fontSize: f13,
                        color: colorValue.homeHintColor,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: w8,
                      mainAxisSpacing: h8,
                      mainAxisExtent: h56,
                    ),
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      final selected = provider.isArticleSelected(article.id);
                      final shared = provider.isArticleShared(article.id);
                      return HomeArticleCard(
                        colorValue: colorValue,
                        article: article,
                        selected: selected,
                        shared: shared,
                        onTap: () => _onToggleArticle(context, article.id),
                        onDeleteTap: () => provider.removeArticle(article.id),
                      );
                    },
                  ),
          ),
          SizedBox(height: h12),
          HomeArticleCreateInput(
            colorValue: colorValue,
            titleController: _titleController,
            contentController: _contentController,
            contentFocusNode: _contentFocusNode,
            contentScrollController: _contentScrollController,
            onSubmit: _onCreateArticle,
          ),
        ],
      ),
    );
  }

  Future<void> _onCreateArticle() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _contentFocusNode.requestFocus();
      return;
    }
    if (content.length > HomeArticleLimits.maxContentLength) {
      if (!mounted) return;
      showHomeShareSnackBar(
        context,
        '单篇文章不超过 ${HomeArticleLimits.maxContentLength} 字',
      );
      _contentFocusNode.requestFocus();
      return;
    }

    final created = await provider.createArticle(
      title: _titleController.text,
      content: _contentController.text,
    );
    if (!mounted) return;

    if (created == null) {
      _contentFocusNode.requestFocus();
      return;
    }

    _titleController.clear();
    _contentController.clear();
    _contentFocusNode.requestFocus();
  }

  Future<void> _onToggleArticle(BuildContext context, String id) async {
    final toggled = await provider.toggleArticleShared(id);
    if (!context.mounted || toggled != null) return;

    final article = provider.articles
        .where((item) => item.id == id)
        .firstOrNull;
    if (article != null &&
        !provider.isArticleSelected(id) &&
        article.charCount > HomeArticleLimits.maxContentLength) {
      showHomeShareSnackBar(
        context,
        '单篇文章不超过 ${HomeArticleLimits.maxContentLength} 字，无法分享',
      );
    }
  }
}
