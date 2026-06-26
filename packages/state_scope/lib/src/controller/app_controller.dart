import 'package:flutter/foundation.dart';

/// 带生命周期钩子和 [update] 通知的 Controller 基类。
/// 替代 GetxController；配合 [ControllerBuilder] 触发重建。
///
/// **ID 策略**：
/// - `update()`：全量刷新，所有监听该 controller 的 [ControllerBuilder] 都会重建。
/// - `update(['name'])`：仅刷新 id='name' 的 Builder。
/// - `update(['name', 'email'])`：同时刷新多个 id 对应的 Builder。
abstract class AppController extends ChangeNotifier {
  bool _initialized = false;

  /// 按 id 注册的监听器，仅 [update](id) 时触发
  final Map<Object, Set<VoidCallback>> _idListeners = {};

  /// 子类重写：一次性初始化（如加载缓存、启动流）。
  void onInit() {}

  /// 子类重写：清理（如取消订阅）。
  void onClose() {}

  /// 在注册后调用一次（如 DI.put 之后）。幂等。
  void initialize() {
    if (!_initialized) {
      _initialized = true;
      onInit();
    }
  }

  /// 通知监听者，[ControllerBuilder] 会随之重建。
  ///
  /// - `update()`：全量刷新（notifyListeners）。
  /// - `update(['name'])`：仅刷新 id='name' 的 Builder。
  /// - `update(['name', 'email'])`：同时刷新多个 id 对应的 Builder。
  void update([List<Object>? ids]) {
    if (ids == null || ids.isEmpty) {
      notifyListeners();
      return;
    }
    for (final id in ids) {
      final callbacks = _idListeners[id];
      if (callbacks != null) {
        for (final cb in List<VoidCallback>.from(callbacks)) {
          cb();
        }
      }
    }
  }

  /// 供 [ControllerBuilder] 按 id 订阅，内部使用。
  void addIdListener(Object id, VoidCallback listener) {
    _idListeners[id] ??= {};
    _idListeners[id]!.add(listener);
  }

  /// 供 [ControllerBuilder] 取消按 id 订阅，内部使用。
  void removeIdListener(Object id, VoidCallback listener) {
    _idListeners[id]?.remove(listener);
  }

  @override
  void dispose() {
    _idListeners.clear();
    onClose();
    super.dispose();
  }
}
