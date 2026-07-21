import 'package:flutter/material.dart';
import 'package:instant_share/features/home/data/home_article_item.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 紧凑型文章卡片（网格展示）。
///
/// 未选中 / 已选中 / 已分享 三种视觉态。
class HomeArticleCard extends StatelessWidget {
  const HomeArticleCard({
    super.key,
    required this.colorValue,
    required this.article,
    required this.selected,
    required this.shared,
    required this.onTap,
    required this.onDeleteTap,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 文章。
  final HomeArticleItem article;

  /// 是否选中。
  final bool selected;

  /// 是否已分享。
  final bool shared;

  /// 点击回调。
  final VoidCallback onTap;

  /// 删除回调。
  final VoidCallback onDeleteTap;

  bool get _isShared => shared;
  bool get _isSelected => selected && !shared;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final iconColor = colorValue.homeUploadIconColor;
    final titleColor = _isShared
        ? HomePalette.switchIconOn
        : _isSelected
        ? HomePalette.articleSelectedForeground
        : iconColor;
    final subtitleColor = _isShared
        ? HomePalette.switchIconOn.withValues(alpha: 0.78)
        : _isSelected
        ? HomePalette.articleSelectedForeground.withValues(alpha: 0.72)
        : iconColor.withValues(alpha: 0.55);
    final borderColor = _isShared
        ? const Color(0xFF34B45B)
        : _isSelected
        ? HomePalette.articleSelectedBorder
        : iconColor.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(s10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isShared
                ? HomePalette.switchOnGradient
                : _isSelected
                ? HomePalette.articleSelectedGradient
                : null,
            color: _isShared || _isSelected
                ? null
                : colorValue.homeUploadButtonFill,
            borderRadius: BorderRadius.circular(s10),
            border: Border.all(
              color: borderColor,
              width: _isShared || _isSelected ? 1.2 : 1,
            ),
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
                    if (_isShared)
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
                      )
                    else if (_isSelected)
                      Padding(
                        padding: EdgeInsets.only(right: w2),
                        child: Text(
                          '已选中',
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
