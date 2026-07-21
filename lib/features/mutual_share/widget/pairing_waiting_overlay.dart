import 'package:flutter/material.dart';
import 'package:instant_share/features/mutual_share/provider/mutual_share_provide.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 等待对方认证。
class PairingWaitingOverlay extends StatelessWidget {
  const PairingWaitingOverlay({
    super.key,
    required this.colorValue,
    required this.provider,
  });

  final ColorValue colorValue;
  final MutualShareProvider provider;

  static const _ink = Color(0xFF4A5260);

  @override
  Widget build(BuildContext context) {
    if (provider.phase != MutualSharePhase.pairingPending) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.28),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: w280),
            child: Material(
              color: colorValue.homeUploadButtonFill,
              borderRadius: BorderRadius.circular(s16),
              child: Padding(
                padding: EdgeInsets.fromLTRB(w24, h28, w24, h20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: w28,
                      height: w28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: h16),
                    Text(
                      '等待对方认证',
                      style: TextStyle(
                        fontSize: f16,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: h6),
                    Text(
                      '${provider.countdownSeconds}s',
                      style: TextStyle(
                        fontSize: f13,
                        color: _ink.withValues(alpha: 0.5),
                      ),
                    ),
                    SizedBox(height: h18),
                    TextButton(
                      onPressed: provider.cancelPairing,
                      style: TextButton.styleFrom(
                        foregroundColor: _ink.withValues(alpha: 0.65),
                      ),
                      child: Text('取消', style: TextStyle(fontSize: f14)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
