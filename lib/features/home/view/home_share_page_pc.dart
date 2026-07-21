part of 'home_share_page.dart';

class _HomeSharePagePcState extends State<HomeSharePage> {
  bool get _useMacOsTitleBarInset =>
      DesktopWindowConfig.usesHiddenTitleBar && Platform.isMacOS;

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
    _showMutualErrorIfNeeded(context);

    final content = Stack(
      children: [
        Column(
          children: [
            SizedBox(height: topInset),
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
            SizedBox(height: h20),
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
                        _FileModeBody(
                          colorValue: colorValue,
                          provider: provider,
                        ),
                        _ArticleShareBody(
                          colorValue: colorValue,
                          provider: provider,
                        ),
                      ],
                    ),
            ),
          ],
        ),
        Positioned(
          top: topInset + h12,
          right: w24,
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
    showHomeShareSnackBar(context, copied ? '分享地址已复制' : '暂无分享地址');
  }

  Future<void> _connectPeer(BuildContext context) async {
    final input = await showConnectPeerDialog(context, colorValue: colorValue);
    if (input == null || input.isEmpty) return;
    await mutual.startPairing(hostInput: input);
    if (!context.mounted) return;
    _showMutualErrorIfNeeded(context);
  }

  void _showMutualErrorIfNeeded(BuildContext context) {
    final error = mutual.errorMessage;
    if (error == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final message = mutual.errorMessage;
      if (message == null) return;
      showHomeShareSnackBar(context, message);
      mutual.clearErrorMessage();
    });
  }
}

class _SharedFilesHeader extends StatelessWidget {
  const _SharedFilesHeader({required this.colorValue});

  /// 颜色配置。
  final ColorValue colorValue;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: w18, vertical: h8),
      decoration: BoxDecoration(
        color: colorValue.homeUploadButtonFill,
        borderRadius: BorderRadius.circular(s24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_shared_outlined,
            size: f16,
            color: colorValue.homeUploadIconColor,
          ),
          SizedBox(width: w6),
          Text(
            '共享文件',
            style: TextStyle(
              fontSize: f13,
              color: colorValue.homeUploadIconColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
