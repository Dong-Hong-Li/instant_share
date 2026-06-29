import 'package:flutter/material.dart';
import 'package:instant_share/features/home/data/home_article_item.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 紧凑型文章卡片（网格展示，已分享 / 未分享通过颜色区分）。
class HomeArticleCard extends StatelessWidget {
  const HomeArticleCard({
    super.key,
    required this.colorValue,
    required this.article,
    required this.shared,
    required this.onTap,
    required this.onDeleteTap,
  });

  final ColorValue colorValue;
  final HomeArticleItem article;
  final bool shared;
  final VoidCallback onTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = colorValue.homeUploadIconColor;
    final titleColor = shared ? HomePalette.switchIconOn : iconColor;
    final subtitleColor = shared
        ? HomePalette.switchIconOn.withValues(alpha: 0.78)
        : iconColor.withValues(alpha: 0.55);
    final borderColor = shared
        ? const Color(0xFF34B45B)
        : iconColor.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(s10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: shared ? HomePalette.switchOnGradient : null,
            color: shared ? null : colorValue.homeUploadButtonFill,
            borderRadius: BorderRadius.circular(s10),
            border: Border.all(color: borderColor, width: shared ? 1.2 : 1),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(w8, h6, w4, h6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.article_outlined, size: f13, color: titleColor),
                    SizedBox(width: w4),
                    Expanded(
                      child: Text(
                        article.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: f12,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                    if (shared)
                      Padding(
                        padding: EdgeInsets.only(right: w2),
                        child: Text(
                          '已分享',
                          style: TextStyle(
                            fontSize: f9,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: onDeleteTap,
                      borderRadius: BorderRadius.circular(s8),
                      child: Padding(
                        padding: EdgeInsets.all(w2),
                        child: Icon(
                          Icons.close,
                          size: f14,
                          color: titleColor.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: h2),
                Text(
                  '${article.charCount} 字',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: f10, color: subtitleColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
