import 'package:flutter/material.dart';
import 'package:instant_share/features/home/data/home_file_format.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 底部文件汇总卡片（参考 VPN 客户端底部节点卡片）。
class HomeSummaryCard extends StatelessWidget {
  const HomeSummaryCard({
    super.key,
    required this.colorValue,
    required this.fileCount,
    required this.totalSize,
    required this.onAddTap,
    required this.onClearTap,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 文件数量。
  final int fileCount;

  /// totalSize。
  final int totalSize;

  /// onAddTap。
  final VoidCallback onAddTap;

  /// onClearTap。
  final VoidCallback onClearTap;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final hasFiles = fileCount > 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: w16, vertical: h12),
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
      child: Row(
        children: [
          Container(
            width: w40,
            height: w40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorValue.homeUploadIconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(s12),
            ),
            child: Icon(
              Icons.folder_open_outlined,
              size: f20,
              color: colorValue.homeUploadIconColor,
            ),
          ),
          SizedBox(width: w12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasFiles ? '已选 $fileCount 个文件' : '尚未选择文件',
                  style: TextStyle(
                    fontSize: f14,
                    fontWeight: FontWeight.w600,
                    color: colorValue.homeUploadIconColor,
                  ),
                ),
                SizedBox(height: h2),
                Text(
                  hasFiles
                      ? '本次已用 ${formatHomeFileSize(totalSize)}'
                      : '点击右侧加号添加文件',
                  style: TextStyle(
                    fontSize: f12,
                    color: colorValue.homeUploadIconColor.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasFiles)
            IconButton(
              onPressed: onClearTap,
              tooltip: '清空',
              icon: Icon(
                Icons.delete_outline,
                size: f20,
                color: colorValue.homeUploadIconColor.withValues(alpha: 0.7),
              ),
            ),
          IconButton(
            onPressed: onAddTap,
            tooltip: '继续添加',
            icon: Icon(
              Icons.add_circle_outline,
              size: f22,
              color: colorValue.homeUploadIconColor,
            ),
          ),
        ],
      ),
    );
  }
}
