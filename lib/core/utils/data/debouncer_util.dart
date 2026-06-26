import 'dart:async';

/// 在事件被触发n秒后再执行回调，如果在这n秒内又被触发，则重新计时
class Debouncer {
  /// 延迟时间
  final Duration delay;

  /// 是否立即执行（首次触发时立即执行，后续触发延迟）
  final bool immediate;

  /// 定时器
  Timer? _timer;

  /// 是否已经执行过
  bool _hasExecuted = false;

  /// 是否处于等待状态
  bool get isPending => _timer?.isActive ?? false;

  /// 要执行的函数
  final void Function() action;

  Debouncer({
    required this.delay,
    this.immediate = false,
    required this.action,
  });

  /// 执行防抖函数
  void call() {
    if (immediate && !_hasExecuted) {
      action();
      _hasExecuted = true;
    }

    _timer?.cancel();

    _timer = Timer(delay, () {
      if (!immediate) {
        action();
      }
      _hasExecuted = false;
    });
  }

  /// 取消防抖
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _hasExecuted = false;
  }

  /// 立即执行并取消防抖
  void flush() {
    _timer?.cancel();
    _timer = null;
    _hasExecuted = false;
    action.call();
  }

  void dispose() {
    cancel();
  }
}
