import 'package:flutter/foundation.dart';

/// Tier 3：异步序列单元，配合 [AppStreamBuilder]。
///
/// [create] 在 Builder **首次挂载**或 **[provider] 引用变化**时调用；取得的流由内部 [StreamBuilder] 监听。
/// 多处同时要监听同一逻辑源时，[create] 宜返回 **广播流**
///（例如对已持有的单订阅流调用 `.asBroadcastStream()`，或共用 `StreamController.broadcast()`）。
@immutable
class AppStreamProvider<T> {
  /// 生成本轮监听所使用的流。
  final Stream<T> Function() create;

  const AppStreamProvider(this.create);
}

/// 参数化异步序列；配合 [AppStreamFamilyBuilder]，语义对齐 Tier 2 family。
@immutable
class AppStreamFamilyProvider<T, Arg> {
  /// 针对给定参数生成流。
  final Stream<T> Function(Arg arg) create;

  const AppStreamFamilyProvider(this.create);
}
