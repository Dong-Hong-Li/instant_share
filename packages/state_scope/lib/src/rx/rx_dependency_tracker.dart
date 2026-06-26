import 'package:flutter/foundation.dart';

/// 在 [Obx] 的 builder 执行期间收集读到的 [Listenable]（通常为 [Rx]）；支持嵌套 [Obx]。
class RxDependencyTracker {
  RxDependencyTracker._();
  static final RxDependencyTracker instance = RxDependencyTracker._();

  final List<RxCollector> _stack = [];

  void reportRead(Listenable rx) {
    if (_stack.isEmpty) return;
    _stack.last.add(rx);
  }

  /// 在 [fn] 执行期间将 [reportRead] 路由到 [collector]。
  U collect<U>(RxCollector collector, U Function() fn) {
    _stack.add(collector);
    try {
      return fn();
    } finally {
      _stack.removeLast();
    }
  }
}

/// 管理单个 [Obx] 与若干 [Rx] 的监听；每次 [clear] 后重新收集。
class RxCollector {
  RxCollector(this._onNotify);

  final VoidCallback _onNotify;

  final Map<Listenable, VoidCallback> _listeners = {};

  void add(Listenable rx) {
    _listeners.putIfAbsent(rx, () {
      void listener() => _onNotify();
      rx.addListener(listener);
      return listener;
    });
  }

  void clear() {
    for (final e in _listeners.entries) {
      e.key.removeListener(e.value);
    }
    _listeners.clear();
  }

  void dispose() => clear();
}
