import 'package:flutter/material.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';

/// 首页右上角「连接对方」入口，风格与问号提示一致。
class ConnectPeerButton extends StatelessWidget {
  const ConnectPeerButton({
    super.key,
    required this.onPressed,
    this.sharing = false,
  });

  final VoidCallback onPressed;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    final iconColor = HomePalette.statusText(
      sharing: sharing,
    ).withValues(alpha: 0.88);

    return Tooltip(
      message: '连接对方设备',
      waitDuration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(s6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: sharing ? 0.22 : 0.16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: sharing ? 0.28 : 0.22),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(s6),
                child: Icon(
                  Icons.add_rounded,
                  size: f20,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
