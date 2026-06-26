import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 展示分享链接二维码。
Future<void> showHomeShareQrDialog(
  BuildContext context, {
  required String shareUrl,
  required ColorValue colorValue,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: colorValue.homeUploadButtonFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: w320),
          child: Padding(
            padding: EdgeInsets.fromLTRB(w24, h24, w24, h20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '扫码访问分享页',
                  style: TextStyle(
                    fontSize: f16,
                    fontWeight: FontWeight.w600,
                    color: colorValue.homeUploadIconColor,
                  ),
                ),
                SizedBox(height: h16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(s12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(w12),
                    child: QrImageView(
                      data: shareUrl,
                      size: w200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: h16),
                SelectableText(
                  shareUrl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: f12,
                    color: colorValue.homeUploadIconColor.withValues(
                      alpha: 0.75,
                    ),
                  ),
                ),
                SizedBox(height: h20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '关闭',
                      style: TextStyle(
                        fontSize: f14,
                        color: colorValue.homeUploadIconColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
