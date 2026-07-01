part of 'home_share_page.dart';

class _HomeSharePagePcState extends State<HomeSharePage> {
  bool get _useMacOsTitleBarInset =>
      DesktopWindowConfig.usesHiddenTitleBar && Platform.isMacOS;

  HomeProvider get provider => widget.provider;
  ColorValue get colorValue => widget.colorValue;

  @override
  Widget build(BuildContext context) {
    final topInset = widget.topInset;
    final isFileMode = provider.shareMode == HomeShareMode.file;

    final content = Stack(
      children: [
        Column(
          children: [
            SizedBox(height: topInset),
            Center(
              child: HomeShareModeTabs(
                colorValue: colorValue,
                sharing: provider.isSharing,
                mode: provider.shareMode,
                onModeChanged: provider.setShareMode,
              ),
            ),
            SizedBox(height: h20),
            Expanded(
              child: CrossFadeSwitcher(
                currentIndex: isFileMode ? 0 : 1,
                children: [
                  _FileModeBody(colorValue: colorValue, provider: provider),
                  _ArticleShareBody(colorValue: colorValue, provider: provider),
                ],
              ),
            ),
          ],
        ),
        if (provider.hasServerInfo)
          Positioned(
            top: topInset + h12,
            right: w24,
            child: HomeServerUrlHint(
              shareUrl: provider.serverShareUrl,
              alternateShareUrls: provider.alternateShareUrls,
              sharing: provider.isSharing,
              onCopyUrl: (url) => _copyServerUrl(context, url),
            ),
          )
        else if (!isFileMode)
          Positioned(
            top: topInset + h12,
            right: w24,
            child: HomeArticleHelpHint(colorValue: colorValue),
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
    showHomeShareSnackBar(context, copied ? '分享地址已复制' : '暂无分享地址');
  }
}
