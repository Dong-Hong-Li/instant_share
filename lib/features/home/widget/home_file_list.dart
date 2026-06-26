import 'package:flutter/material.dart';
import 'package:instant_share/features/home/data/home_file_format.dart';
import 'package:instant_share/features/home/data/home_file_item.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 已选文件列表（表格样式，支持删除）。
class HomeFileList extends StatelessWidget {
  const HomeFileList({
    super.key,
    required this.colorValue,
    required this.files,
    required this.onRemove,
  });

  final ColorValue colorValue;
  final List<HomeFileItem> files;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorValue.homeUploadButtonFill.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(s16),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: w12, vertical: h8),
          itemCount: files.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: colorValue.homeUploadIconColor.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final file = files[index];
            return _Row(
              colorValue: colorValue,
              file: file,
              onRemove: () => onRemove(file.id),
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.colorValue,
    required this.file,
    required this.onRemove,
  });

  final ColorValue colorValue;
  final HomeFileItem file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w8, vertical: h8),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: f16,
            color: colorValue.homeUploadIconColor.withValues(alpha: 0.6),
          ),
          SizedBox(width: w8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  flex: 7,
                  child: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: f13,
                      fontWeight: FontWeight.w500,
                      color: colorValue.homeUploadIconColor,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
          SizedBox(width: w12),
          Text(
            formatHomeFileSize(file.size),
            style: TextStyle(
              fontSize: f12,
              color: colorValue.homeUploadIconColor.withValues(alpha: 0.6),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: '删除',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: w32, minHeight: w32),
            icon: Icon(
              Icons.close,
              size: f16,
              color: colorValue.homeUploadIconColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
