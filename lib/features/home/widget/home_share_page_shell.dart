import 'dart:io';

import 'package:flutter/material.dart';
import 'package:instant_share/core/config/desktop_window_config.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';
import 'package:window_manager/window_manager.dart';

void showHomeShareSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// PC 分享页通用壳层：顶部 inset + 可选右上角 + macOS 拖拽区。
class HomeSharePageShell extends StatelessWidget {
  const HomeSharePageShell({
    super.key,
    required this.topInset,
    required this.body,
    this.topRight,
  });

  final double topInset;
  final Widget body;
  final Widget? topRight;

  bool get _useMacOsTitleBarInset =>
      DesktopWindowConfig.usesHiddenTitleBar && Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        body,
        if (topRight != null)
          Positioned(top: topInset + h12, right: w24, child: topRight!),
      ],
    );

    if (!_useMacOsTitleBarInset) return content;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + h32,
          child: const DragToMoveArea(child: SizedBox.expand()),
        ),
        content,
      ],
    );
  }
}
