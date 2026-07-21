import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端统一圆角窗口外框（Windows / Linux / macOS 一致）。
///
/// window_manager 自带的 [VirtualWindowFrame] 在 Windows 上不会裁剪圆角，
/// 此处对所有桌面平台应用相同的 [borderRadius] 与阴影。
class DesktopWindowFrame extends StatefulWidget {
  const DesktopWindowFrame({
    super.key,
    required this.child,
    this.borderRadius = 12,
  });

  /// 子组件。
  final Widget child;

  /// borderRadius。
  final double borderRadius;

  /// 创建状态对象。
  @override
  State<DesktopWindowFrame> createState() => _DesktopWindowFrameState();
}

class _DesktopWindowFrameState extends State<DesktopWindowFrame>
    with WindowListener {
  bool _isFocused = true;
  bool _isMaximized = false;
  bool _isFullScreen = false;

  static final _isLinux = !kIsWeb && Platform.isLinux;
  static final _isWindows = !kIsWeb && Platform.isWindows;
  static final _isDesktop =
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// 初始化状态。
  @override
  void initState() {
    if (_isDesktop) {
      windowManager.addListener(this);
    }
    super.initState();
  }

  /// 释放资源。
  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  bool get _expanded => _isMaximized || _isFullScreen;

  double get _radius => _expanded ? 0 : widget.borderRadius;

  Widget _buildFramedChild(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: _expanded ? 0 : 1,
        ),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          if (!_expanded)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: Offset(0, _isFocused ? 4 : 2),
              blurRadius: 8,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: widget.child,
      ),
    );
  }

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return widget.child;

    final framed = _buildFramedChild(context);

    if (_isLinux) {
      return DragToResizeArea(
        enableResizeEdges: _expanded ? [] : null,
        child: framed,
      );
    }

    if (_isWindows) {
      return DragToResizeArea(
        enableResizeEdges: _expanded
            ? []
            : [ResizeEdge.topLeft, ResizeEdge.top, ResizeEdge.topRight],
        child: framed,
      );
    }

    return framed;
  }

  /// onWindowFocus。
  @override
  void onWindowFocus() => setState(() => _isFocused = true);

  /// onWindowBlur。
  @override
  void onWindowBlur() => setState(() => _isFocused = false);

  /// onWindowMaximize。
  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  /// onWindowUnmaximize。
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  /// onWindowEnterFullScreen。
  @override
  void onWindowEnterFullScreen() => setState(() => _isFullScreen = true);

  /// onWindowLeaveFullScreen。
  @override
  void onWindowLeaveFullScreen() => setState(() => _isFullScreen = false);
}
