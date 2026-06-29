import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/features/home/data/home_article_input_scroll.dart';
import 'package:instant_share/features/home/provider/provider.dart';
import 'package:instant_share/features/home/widget/home_article_card.dart';
import 'package:instant_share/features/home/widget/home_article_create_input.dart';
import 'package:instant_share/features/home/widget/home_article_help_hint.dart';
import 'package:instant_share/features/home/widget/home_share_page_shell.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 分享文章页。
class HomeArticleSharePage extends StatefulWidget {
  const HomeArticleSharePage({
    super.key,
    required this.colorValue,
    required this.provider,
    required this.topInset,
  });

  final ColorValue colorValue;
  final HomeProvider provider;
  final double topInset;

  @override
  State<HomeArticleSharePage> createState() => _HomeArticleSharePageState();
}

class _HomeArticleSharePageState extends State<HomeArticleSharePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocusNode;
  late final ScrollController _contentScrollController;

  HomeProvider get provider => widget.provider;
  ColorValue get colorValue => widget.colorValue;

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

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final articles = provider.articles;

    return HomeSharePageShell(
      topInset: widget.topInset,
      topRight: HomeArticleHelpHint(colorValue: colorValue),
      body: Column(
        children: [
          SizedBox(height: widget.topInset + h20),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(w24, 0, w24, h20),
              child: Column(
                children: [
                  SizedBox(height: h8),
                  Expanded(
                    child: articles.isEmpty
                        ? Center(
                            child: Text(
                              '暂无文章',
                              style: TextStyle(
                                fontSize: f13,
                                color: colorValue.homeHintColor,
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: w8,
                                  mainAxisSpacing: h8,
                                  mainAxisExtent: h56,
                                ),
                            itemCount: articles.length,
                            itemBuilder: (context, index) {
                              final article = articles[index];
                              final shared = provider.isArticleShared(
                                article.id,
                              );
                              return HomeArticleCard(
                                colorValue: colorValue,
                                article: article,
                                shared: shared,
                                onTap: () =>
                                    provider.toggleArticleShared(article.id),
                                onDeleteTap: () =>
                                    provider.removeArticle(article.id),
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
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCreateArticle() async {
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
}
