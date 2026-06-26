import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 分享中：查看二维码 / 复制地址。
class HomeShareLinkActions extends StatelessWidget {
  const HomeShareLinkActions({
    super.key,
    required this.colorValue,
    required this.onQrTap,
    required this.onCopyTap,
  });

  final ColorValue colorValue;
  final VoidCallback onQrTap;
  final VoidCallback onCopyTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            colorValue: colorValue,
            icon: Icons.qr_code_2_outlined,
            label: '查看二维码',
            onTap: onQrTap,
          ),
        ),
        SizedBox(width: w12),
        Expanded(
          child: _ActionButton(
            colorValue: colorValue,
            icon: Icons.link_outlined,
            label: '复制地址',
            onTap: onCopyTap,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.colorValue,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ColorValue colorValue;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorValue.homeUploadButtonFill,
      borderRadius: BorderRadius.circular(s16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(s16),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w12, vertical: h12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: f18, color: colorValue.homeUploadIconColor),
              SizedBox(width: w8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: f14,
                    fontWeight: FontWeight.w600,
                    color: colorValue.homeUploadIconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
