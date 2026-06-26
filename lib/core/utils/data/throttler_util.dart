import 'dart:async';

/// 在指定时间内只执行一次函数，如果在这个时间内多次触发，只有一次生效
class Throttler {
  /// 时间间隔
  final Duration duration;

  /// 是否在开始时执行（leading）
  final bool leading;

  /// 是否在结束时执行（trailing）
  final bool trailing;

  /// 定时器
  Timer? _timer;

  /// 是否已经执行过
  bool _isThrottled = false;

  /// 最后一次执行的回调
  void Function()? _lastAction;

  /// 最后一次执行的时间
  DateTime? _lastExecuteTime;

  /// 是否处于节流状态
  bool get isThrottled => _isThrottled;

  /// 要执行的函数
  final void Function() action;

  /// 距离上次执行的时间（毫秒）
  int? get timeSinceLastExecute {
    if (_lastExecuteTime == null) return null;
    return DateTime.now().difference(_lastExecuteTime!).inMilliseconds;
  }

  Throttler({
    required this.duration,
    this.leading = true,
    this.trailing = false,
    required this.action,
  });

  /// 执行节流函数
  void call() {
    _lastAction = () {
      action();
    };

    if (!_isThrottled) {
      if (leading) {
        action();
        _lastExecuteTime = DateTime.now();
      }

      _isThrottled = true;

      _timer = Timer(duration, () {
        if (trailing && _lastAction != null) {
          _lastAction!();
          _lastExecuteTime = DateTime.now();
        }
        _isThrottled = false;
        _lastAction = null;
        _timer = null;
      });
    }
  }

  /// 取消节流
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _isThrottled = false;
    _lastAction = null;
    _lastExecuteTime = null;
  }

  /// 立即执行并重置节流状态
  void flush() {
    _timer?.cancel();
    _timer = null;
    _isThrottled = false;
    _lastAction = null;
    action.call();
    _lastExecuteTime = DateTime.now();
  }

  void dispose() {
    cancel();
  }
}
