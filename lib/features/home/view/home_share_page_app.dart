part of 'home_share_page.dart';

class _HomeSharePageAppState extends State<HomeSharePage> {
  /// 状态提供者。
  HomeProvider get provider => widget.provider;

  /// mutual。
  MutualShareProvider get mutual => widget.mutual;

  /// 颜色配置。
  ColorValue get colorValue => widget.colorValue;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final topInset = widget.topInset;
    final isFileMode = provider.shareMode == HomeShareMode.file;
    final joinedRoom = mutual.joinedRoom;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topInset),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w16),
              child: Row(
                children: [
                  _AppLogo(colorValue: colorValue),
                  SizedBox(width: w8),
                  Expanded(
                    child: Text(
                      '极速分享',
                      style: TextStyle(
                        fontSize: f18,
                        fontWeight: FontWeight.w700,
                        color: colorValue.homeTitleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: h12),
            Center(
              child: joinedRoom
                  ? _SharedFilesHeader(colorValue: colorValue)
                  : HomeShareModeTabs(
                      colorValue: colorValue,
                      sharing: provider.isSharing,
                      mode: provider.shareMode,
                      onModeChanged: provider.setShareMode,
                    ),
            ),
            SizedBox(height: h12),
            Expanded(
              child: joinedRoom
                  ? _JoinedRoomBody(
                      colorValue: colorValue,
                      provider: provider,
                      mutual: mutual,
                    )
                  : CrossFadeSwitcher(
                      currentIndex: isFileMode ? 0 : 1,
                      children: [
                        _AppFileModeBody(
                          colorValue: colorValue,
                          provider: provider,
                        ),
                        _AppArticleShareBody(
                          colorValue: colorValue,
                          provider: provider,
                        ),
                      ],
                    ),
            ),
          ],
        ),
        Positioned(
          top: topInset + h8,
          right: w16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.hasServerInfo)
                HomeServerUrlHint(
                  shareUrl: provider.serverShareUrl,
                  alternateShareUrls: provider.alternateShareUrls,
                  sharing: provider.isSharing,
                  onCopyUrl: (url) => _copyServerUrl(context, url),
                )
              else if (!isFileMode && !joinedRoom)
                HomeArticleHelpHint(colorValue: colorValue),
              SizedBox(width: w4),
              ConnectPeerButton(
                sharing: provider.isSharing || joinedRoom,
                onPressed: () => _connectPeer(context),
              ),
            ],
          ),
        ),
        PairingWaitingOverlay(colorValue: colorValue, provider: mutual),
      ],
    );
  }

  Future<void> _copyServerUrl(BuildContext context, String url) async {
    final copied = await provider.copyShareUrlToClipboard(url);
    if (!context.mounted) return;
    showHomeShareSnackBar(context, copied ? '分享地址已复制' : '暂无分享地址');
  }

  Future<void> _connectPeer(BuildContext context) async {
    final input = await showConnectPeerDialog(context, colorValue: colorValue);
    if (input == null || input.isEmpty) return;
    await mutual.startPairing(hostInput: input);
    if (!context.mounted) return;
    final error = mutual.errorMessage;
    if (error != null) {
      showHomeShareSnackBar(context, error);
      mutual.clearErrorMessage();
    }
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.colorValue});

  /// 颜色配置。
  final ColorValue colorValue;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: w36,
      height: w36,
      decoration: BoxDecoration(
        color: colorValue.homeUploadButtonFill,
        borderRadius: BorderRadius.circular(s10),
      ),
      child: Icon(Icons.bolt, size: f20, color: colorValue.homeUploadIconColor),
    );
  }
}

class _AppFileModeBody extends StatelessWidget {
  const _AppFileModeBody({required this.colorValue, required this.provider});

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
        SizedBox(height: h22),
        HomeActionButton(
          colorValue: colorValue,
          state: actionState,
          enabled: !provider.isPicking && !provider.isShareBusy,
          onTap: provider.toggleSharing,
        ),
        SizedBox(height: h12),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: f15,
            fontWeight: FontWeight.w600,
            color: HomePalette.statusText(sharing: isSharing),
          ),
        ),
        SizedBox(height: h6),
        HomeShareCountdown(colorValue: colorValue, active: isSharing),
        if (isSharing) ...[
          SizedBox(height: h12),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(w16, 0, w16, h16),
      child: Column(
        children: [
          shareControls,
          SizedBox(height: h16),
          if (hasFiles) ...[
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

class _AppArticleShareBody extends StatefulWidget {
  const _AppArticleShareBody({
    required this.colorValue,
    required this.provider,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 状态提供者。
  final HomeProvider provider;

  /// 创建状态对象。
  @override
  State<_AppArticleShareBody> createState() => _AppArticleShareBodyState();
}

class _AppArticleShareBodyState extends State<_AppArticleShareBody> {
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
    _contentFocusNode = FocusNode();
    _contentScrollController = ScrollController();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: w16),
            child: articles.isEmpty
                ? Center(
                    child: Text(
                      isSharing ? '创建文章后点击卡片即可分享' : '暂无文章',
                      style: TextStyle(
                        fontSize: f14,
                        color: colorValue.homeHintColor,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: w8,
                      mainAxisSpacing: h8,
                      mainAxisExtent: h64,
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
        ),
        SafeArea(
          top: false,
          minimum: EdgeInsets.fromLTRB(w16, h8, w16, h30),
          child: HomeArticleCreateInput(
            colorValue: colorValue,
            titleController: _titleController,
            contentController: _contentController,
            contentFocusNode: _contentFocusNode,
            contentScrollController: _contentScrollController,
            onSubmit: _onCreateArticle,
          ),
        ),
      ],
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
