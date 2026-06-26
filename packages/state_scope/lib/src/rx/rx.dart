import 'package:flutter/foundation.dart';

import 'rx_dependency_tracker.dart';

/// GetX 风格的响应式标量；在 [Obx] 的 builder 中读取 [.value] 会登记依赖，变更时仅重建对应 [Obx]。
///
/// 在回调中若不想登记依赖，请使用 [peek]。
class Rx<T> extends ChangeNotifier {
  Rx(this._value);

  T _value;

  T get value {
    RxDependencyTracker.instance.reportRead(this);
    return _value;
  }

  set value(T next) {
    if (_value == next) return;
    _value = next;
    notifyListeners();
  }

  /// 仅读当前值，不触发 [Obx] 依赖收集。
  T get peek => _value;
}
