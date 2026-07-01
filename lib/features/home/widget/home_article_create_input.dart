import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/features/home/data/home_article_input_scroll.dart';
import 'package:instant_share/features/home/data/home_article_limits.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 创建文章输入区：回车创建，Shift/修饰键+回车换行。
class HomeArticleCreateInput extends StatelessWidget {
  const HomeArticleCreateInput({
    super.key,
    required this.colorValue,
    required this.titleController,
    required this.contentController,
    required this.contentFocusNode,
    required this.contentScrollController,
    required this.onSubmit,
  });

  final ColorValue colorValue;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final FocusNode contentFocusNode;
  final ScrollController contentScrollController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final iconColor = colorValue.homeUploadIconColor;
    final hintColor = iconColor.withValues(alpha: 0.45);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorValue.homeUploadButtonFill,
        borderRadius: BorderRadius.circular(s16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: s16,
            offset: Offset(0, h4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(w16, h12, w16, h8),
            child: TextField(
              controller: titleController,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                fontSize: f14,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '文章标题（可选）',
                hintStyle: TextStyle(
                  fontSize: f14,
                  fontWeight: FontWeight.w600,
                  color: hintColor,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: iconColor.withValues(alpha: 0.08)),
          Padding(
            padding: EdgeInsets.fromLTRB(w16, h4, w8, h4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const HomeArticleInputScrollBehavior(),
                    child: TextField(
                      focusNode: contentFocusNode,
                      controller: contentController,
                      scrollController: contentScrollController,
                      scrollPhysics: const ClampingScrollPhysics(),
                      minLines: 2,
                      maxLines: 4,
                      maxLength: HomeArticleLimits.maxContentLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      style: TextStyle(
                        fontSize: f14,
                        height: 1.5,
                        color: iconColor,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: HomeArticleInputShortcuts.contentHintText,
                        hintStyle: TextStyle(
                          fontSize: f14,
                          height: 1.5,
                          color: hintColor,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onSubmit,
                  tooltip: '创建文章',
                  icon: Icon(
                    Icons.add_circle_outline,
                    size: f22,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
