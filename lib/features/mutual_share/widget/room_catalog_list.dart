import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/infrastructure/websocket/room_ws_models.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

class RoomCatalogList extends StatelessWidget {
  const RoomCatalogList({
    super.key,
    required this.colorValue,
    required this.entries,
  });

  final ColorValue colorValue;
  final List<SharedEntryDto> entries;

  @override
  Widget build(BuildContext context) {
    final ink = colorValue.homeUploadIconColor;

    if (entries.isEmpty) {
      return Center(
        child: Text(
          '共享文件列表为空',
          style: TextStyle(
            fontSize: f14,
            color: colorValue.homeTitleColor.withValues(alpha: 0.65),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: w24, vertical: h12),
      itemCount: entries.length,
      separatorBuilder: (_, _) => SizedBox(height: h8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorValue.homeUploadButtonFill,
            borderRadius: BorderRadius.circular(s14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: s14,
                offset: Offset(0, h3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: w12, vertical: h10),
            child: Row(
              children: [
                Container(
                  width: w36,
                  height: w36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(s10),
                  ),
                  child: Icon(
                    Icons.insert_drive_file_outlined,
                    size: f18,
                    color: ink,
                  ),
                ),
                SizedBox(width: w10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: f14,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      SizedBox(height: h3),
                      Text(
                        '${entry.ownerDisplayName ?? entry.ownerId} · ${_sizeText(entry.size)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: f12,
                          color: ink.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '复制下载链接',
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: entry.downloadUri.toString()),
                  ),
                  icon: Icon(
                    Icons.link_rounded,
                    size: f20,
                    color: ink.withValues(alpha: 0.7),
                  ),
                ),
                IconButton(
                  tooltip: '打开下载',
                  onPressed: () => _open(entry.downloadUri),
                  icon: Icon(
                    Icons.download_rounded,
                    size: f20,
                    color: ink.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _open(Uri uri) async {
    if (Platform.isMacOS) {
      await Process.run('open', [uri.toString()]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', uri.toString()]);
    } else {
      await Process.run('xdg-open', [uri.toString()]);
    }
  }

  static String _sizeText(int size) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = size.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return unit == 0
        ? '${value.toInt()} ${units[unit]}'
        : '${value.toStringAsFixed(1)} ${units[unit]}';
  }
}
