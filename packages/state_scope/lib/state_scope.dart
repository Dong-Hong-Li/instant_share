/// 轻量级 DI + 状态管理框架，零第三方依赖。
///
/// 四层 API：
/// - **Tier 1**：`DI` + `AppController` + `ControllerBuilder` — 全局单例、简单场景。
/// - **页面内异步/组合状态**：推荐在应用层使用 **flutter_riverpod**（根结点 `ProviderScope`，页面可参考工程内 `BaseStatePage`）。
/// - **Tier 2（Rx）**：`Rx` + `Obx` — GetX 风格细粒度响应式（字段级局部刷新）。
/// - **Tier 3（Stream）**：`AppStreamProvider` + `AppStreamBuilder` — 异步序列（内部 [StreamBuilder]）。
///
/// ```dart
/// import 'package:state_scope/state_scope.dart';
/// ```
library;

// Tier 1：DI + Controller + Builder（简单场景，全局单例）
export 'src/di/di.dart';
export 'src/di/impl/simple_service_locator.dart';
export 'src/controller/app_controller.dart';
export 'src/controller/controller_builder.dart';

// Tier 2：Rx + Obx（GetX 风格细粒度响应式）
export 'src/rx/rx.dart';
export 'src/rx/obx.dart';
export 'src/rx/rx_extensions.dart';

// Tier 3：声明式 Stream + StreamBuilder（异步序列）
export 'src/stream/app_stream_provider.dart';
export 'src/stream/app_stream_builder.dart';
