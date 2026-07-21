import 'dart:async';

import 'package:flutter/material.dart';
import 'package:instant_share/core/utils/data/date_time_util.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';

/// 分享倒计时（暂未接入自动关闭，默认 999 分钟）。
///
/// [active] 为 true 时开始倒计时，false 时停止并隐藏。
class HomeShareCountdown extends StatefulWidget {
  const HomeShareCountdown({
    super.key,
    required this.colorValue,
    required this.active,
    this.totalMinutes = 999,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 是否激活。
  final bool active;

  /// totalMinutes。
  final int totalMinutes;

  /// 创建状态对象。
  @override
  State<HomeShareCountdown> createState() => _HomeShareCountdownState();
}

class _HomeShareCountdownState extends State<HomeShareCountdown> {
  Timer? _timer;

  late int _remainingSeconds;

  /// 初始化状态。
  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.totalMinutes * 60;
    if (widget.active) _start();
  }

  /// didUpdate组件。
  @override
  void didUpdateWidget(covariant HomeShareCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _remainingSeconds = widget.totalMinutes * 60;
      _start();
    } else if (!widget.active && oldWidget.active) {
      _stop();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _stop();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放资源。
  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: !widget.active
          ? const SizedBox.shrink()
          : Text(
              DateTimeUtil.second2HMS(_remainingSeconds),
              style: TextStyle(
                fontSize: f20,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: HomePalette.countdownText(sharing: widget.active),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
    );
  }
}
