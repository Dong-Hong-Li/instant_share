# state_scope

轻量级 **DI + 状态管理** 框架，零第三方依赖（仅依赖 Flutter SDK）。

设计为四层 API，可按场景复杂度自由选择：

| 层级 | 适用场景 | 核心 API |
|------|---------|----------|
| **Tier 1** | 全局单例、简单页面 | `DI` / `AppController` / `ControllerBuilder` |
| **（宿主工程）** | 页面级/功能级状态、autoDispose / family 等 | **[flutter_riverpod](https://pub.dev/packages/flutter_riverpod)**（`ProviderScope`、`ref.watch` …） |
| **Tier 2** | 字段级局部刷新、贴近 GetX `Rx` 心智 | `Rx` / `Obx` / `.rx` 扩展 |
| **Tier 3** | 异步序列、定时推送/WebSocket 等 | `AppStreamProvider` / `AppStreamBuilder`（及 family 变体） |

---

## 快速开始

```yaml
# pubspec.yaml
dependencies:
  state_scope:
    path: packages/state_scope
```

```dart
import 'package:state_scope/state_scope.dart';
```

### 独立可运行案例（插件标准示例）

仓库内 **`example/`** 为不依赖主工程的完整 Demo（三 Tab：Tier1 DI / Tier1 UI / Tier2 Provider）。

```bash
cd packages/state_scope/example
flutter pub get
flutter run
```

说明见 **`example/README.md`**。

---

## Tier 1：DI + Controller + Builder

适合全局单例（主题、用户信息、网络层）和简单页面状态。

### 1. DI — 依赖注入

`DI` 是一个静态门面，内置 `SimpleServiceLocator`，开箱即用，无需手动初始化。

```dart
// 注册
DI.put(AppThemeController()..initialize(), permanent: true);

// 获取
final ctrl = DI.find<AppThemeController>();

// 删除（permanent 实例需 force: true）
await DI.delete<AppThemeController>(force: true);

// 是否已注册
DI.isRegistered<AppThemeController>(); // true / false
```

#### 懒加载

首次 `find` 时才创建实例，节省启动开销：

```dart
DI.lazyPut<HeavyService>(() => HeavyService());

// 首次调用时触发 HeavyService() 构造
final svc = DI.find<HeavyService>();
```

#### 异步注册

需要 `await` 才能拿到实例的场景（如读数据库、网络初始化）：

```dart
final db = await DI.putAsync<Database>(() async {
  return await Database.open('app.db');
});
```

#### tag 多实例

同一类型注册多个实例：

```dart
DI.put(ApiClient('https://api-a.com'), tag: 'a');
DI.put(ApiClient('https://api-b.com'), tag: 'b');

final clientA = DI.find<ApiClient>(tag: 'a');
```

#### permanent 保护

`permanent: true` 的实例调用 `delete` 不会被删除，除非显式传 `force: true`：

```dart
DI.put(GlobalConfig(), permanent: true);

await DI.delete<GlobalConfig>();          // false — 未删除
await DI.delete<GlobalConfig>(force: true); // true — 强制删除
```

#### 替换底层实现（可选）

默认使用 `SimpleServiceLocator`。如有自定义实现，可在启动时替换：

```dart
DI.init(MyCustomLocator());
```

---

### 2. AppController — 控制器基类

继承 `ChangeNotifier`，提供生命周期钩子和 `update()` 通知。

```dart
class CounterController extends AppController {
  int count = 0;

  @override
  void onInit() {
    // 一次性初始化（加载缓存、启动流等）
  }

  @override
  void onClose() {
    // 清理（取消订阅等）
  }

  void increment() {
    count++;
    update(); // 通知所有监听者重建
  }
}
```

#### ID 策略 — 局部刷新

`update()` 支持传入 id 列表，只通知订阅了对应 id 的 `ControllerBuilder`，减少不必要的 build：

```dart
class FormController extends AppController {
  String name = '';
  String email = '';

  void updateName(String v) {
    name = v;
    update(['name']); // 仅刷新 id='name' 的 Builder
  }

  void updateEmail(String v) {
    email = v;
    update(['email']); // 仅刷新 id='email' 的 Builder
  }

  void updateAll(String n, String e) {
    name = n;
    email = e;
    update(['name', 'email']); // 同时刷新两个
  }
}
```

---

### 3. ControllerBuilder — 响应式 Widget

从 `DI` 自动解析控制器，当 `update()` 时重建。

```dart
// 全量监听
ControllerBuilder<CounterController>(
  builder: (ctrl) => Text('${ctrl.count}'),
)

// 按 ID 局部监听
ControllerBuilder<FormController>(
  id: 'name',
  builder: (ctrl) => Text(ctrl.name),
)

// 带 tag
ControllerBuilder<ApiController>(
  tag: 'secondary',
  builder: (ctrl) => Text(ctrl.status),
)
```

---

## Tier 2：声明式 Provider + Consumer（**已从本包移除，请改用 flutter_riverpod**）

> **`AppStateProvider` / `AppScope` / `AppConsumer` 不再提供**。页面级状态请使用 [flutter_riverpod](https://pub.dev/packages/flutter_riverpod)（根结点 `ProviderScope`，`ConsumerStatefulWidget` + `WidgetRef`）。  
> 以下内容为原 Tier 2 文档存档，便于迁移对照，**代码示例已不可用**。

适合页面级/功能级状态，需要 **autoDispose**（离屏自动释放）或 **family**（按参数各一份实例）。

灵感来自 Riverpod，但底层用纯 `ChangeNotifier`，无第三方依赖。`AppStateProvider<T>` / `AppFamilyProvider<T, Arg>` 要求 **`T extends ChangeNotifier`**（例如继承你项目里的 `AppController`），以便 `ref.watch` 能监听 `notifyListeners` 并正确参与 `autoDispose` 计数。

### 1. 声明 Provider

在顶层文件中声明，全局可用：

```dart
// 普通 Provider
final counterProvider = AppStateProvider<CounterController>(
  () => CounterController()..initialize(),
);

// autoDispose — 无人 watch 时自动释放
final cacheProvider = AppStateProvider<CacheController>(
  () => CacheController(),
  autoDispose: true,
);

// family — 按参数各一份实例
final userProvider = AppFamilyProvider<UserRepoController, int>(
  (userId) => UserRepoController(userId),
  autoDispose: true,
);
```

### 2. 提供 AppScope

在根节点包裹 `AppScope`，作为状态容器：

```dart
void main() {
  runApp(
    AppScope(
      child: MyApp(),
    ),
  );
}
```

### 3. 消费 — AppConsumer

用 `ref.watch` 监听，数据变化时自动重建：

```dart
AppConsumer(
  builder: (context, ref) {
    final counter = ref.watch(counterProvider);
    return Text('${counter.count}');
  },
)
```

`ref.read` 只读取当前值，不触发重建（适合在事件回调中使用）：

```dart
onPressed: () {
  ref.read(counterProvider).increment();
}
```

#### Family 用法

```dart
AppConsumer(
  builder: (context, ref) {
    final user = ref.watchFamily(userProvider, 42);
    return Text(user.name);
  },
)
```

### 4. AppConsumerWidget — 更简洁的写法

如果整个页面都需要 ref，继承 `AppConsumerWidget`：

```dart
class MyPage extends AppConsumerWidget {
  const MyPage({super.key});

  @override
  Widget buildWithRef(BuildContext context, AppRef ref) {
    final counter = ref.watch(counterProvider);
    return Scaffold(
      body: Center(child: Text('${counter.count}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.increment(),
        child: Icon(Icons.add),
      ),
    );
  }
}
```

---

## autoDispose 原理

基于引用计数：

1. `ref.watch(provider)` 时 `watchCount + 1`
2. Widget dispose 时 `watchCount - 1`
3. 当 `watchCount` 降为 0 且 `autoDispose: true`，容器自动调用 `dispose()` 并移除实例
4. 下次再 `watch` 时重新 `create()`

---

## 两层 API 如何选择

| 需求 | 推荐 |
|------|------|
| 全局单例（主题、网络、配置） | Tier 1：`DI.put` + `ControllerBuilder` |
| 页面级状态（仅在页面存活期间有效） | Tier 1：`initState` 中 `DI.put`，`dispose` 中 `DI.delete` |
| 需要离屏自动释放 | **flutter_riverpod**：`autoDispose` / 等价 Provider |
| 同类型按参数各一份 | **flutter_riverpod**：`family`（或代码生成） |
| 局部刷新（减少 build 范围） | Tier 1：`update(['id'])` + `ControllerBuilder(id: ...)` |

两层可混用，互不冲突。

---

## 页面级状态（如 `lib/features`）怎么选？

**默认**：新页面、简单页面继续用 **Tier 1**——和现有模板一致，不强制包 `AppScope`。

### 约定（团队可照抄）

1. **全局 / 长生命周期**（主题、当前用户、全局配置）  
   - 用 **Tier 1**：`DI.put(..., permanent: true)` 或在 `main` 里注册，页面用 `ControllerBuilder` 或 `DI.find`。

2. **仅随某页存在的 Controller**（首页、详情、设置页等）  
   - **优先 Tier 1**：`State` 里 `initState` → `DI.put(XXXController()..initialize())`，`dispose` → `DI.delete<XXXController>()`。  
   - 生命周期写在页面里，语义清楚，不依赖根组件是否包 `AppScope`。

3. **何时改用 Tier 2**  
   - 经常忘记 `DI.delete`，或页面多、难统一 code review。  
   - 单页多个独立状态单元，希望声明式 `watch`，而不是一个大 Controller 堆字段。  
   - 需要 **按路由参数各一份实例**（如 `userId`），用 `AppFamilyProvider` 比 `DI` + 手写 map/tag 更省事。  
   - 使用 Tier 2 时：**根上必须包 `AppScope`**，且用 `AppConsumer` / `AppConsumerWidget` 包住会 `ref.watch` 的子树，这样离屏后 `autoDispose` 才会生效。

### Tier 1 页面模板（示意）

```dart
class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    DI.put(HomeController()..initialize());
  }

  @override
  void dispose() {
    DI.delete<HomeController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ControllerBuilder<HomeController>(
      builder: (c) => Scaffold(/* ... */),
    );
  }
}
```

### Tier 2 页面模板（示意，需根节点已有 `AppScope`）

```dart
// 顶层或 feature 内
final homeControllerProvider = AppStateProvider<HomeController>(
  () => HomeController()..initialize(),
  autoDispose: true,
);

// 页面
class HomePage extends AppConsumerWidget {
  const HomePage({super.key});

  @override
  Widget buildWithRef(BuildContext context, AppRef ref) {
    final c = ref.watch(homeControllerProvider);
    return Scaffold(/* ... */);
  }
}
```

---

## Tier 2：Rx + Obx（GetX 风格）

**不依赖 `AppScope`**。在 `Obx` 的 builder 里读取 `Rx.value` 即自动订阅，变更时只重建该 `Obx`。

### 基本用法

```dart
final count = Rx(0);
// 或 0.rx、'hello'.rx

Column(
  children: [
    Obx(() => Text('${count.value}')),
    FilledButton(
      onPressed: () => count.value = count.peek + 1, // peek：不登记依赖
      child: const Text('+1'),
    ),
  ],
);
```

### 扩展 `.rx`

```dart
final n = 0.rx;
final s = 'a'.rx;
```

StatefulWidget 内持有的 `Rx` 需在 `dispose` 中调用 `dispose()`（与 `ChangeNotifier` 相同）。

---

## Tier 3：声明式 Stream / StreamBuilder

适合定时器、`Stream.periodic`、WebSocket、原生平台 Channel 等 **异步序列**。**不依赖 `AppScope`**，可与 Tier 1 / 2 同屏混用。

### AppStreamProvider + AppStreamBuilder

```dart
final ticksProvider = AppStreamProvider<int>(
  () => Stream.periodic(const Duration(seconds: 1), (i) => i),
);

AppStreamBuilder<int>(
  provider: ticksProvider,
  builder: (context, snapshot) {
    if (snapshot.hasError) return Text('${snapshot.error}');
    if (!snapshot.hasData) return const CircularProgressIndicator.adaptive();
    return Text('tick: ${snapshot.data}');
  },
);
```

### Family（按参数各一条流）

```dart
final lineFeedProvider = AppStreamFamilyProvider<String, int>(
  (lineNo) => api.subscribeLine(lineNo),
);

AppStreamFamilyBuilder<String, int>(
  provider: lineFeedProvider,
  arg: selectedLineNo,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    return Text(snapshot.data!);
  },
);
```

同一 `AppStreamProvider` 在树上多处使用时，每次挂载都会调用 `create()`；若需共用 **单订阅** `Stream`，请改为 **广播**（如 `.asBroadcastStream()`）或在 `create` 内返回各自独立的管道。

---

## 目录结构

```
lib/
  state_scope.dart             # barrel export
  src/
    di/
      di.dart
      impl/
        simple_service_locator.dart
    controller/
      app_controller.dart
      controller_builder.dart
    rx/
      rx.dart
      obx.dart
      rx_extensions.dart
      rx_dependency_tracker.dart
    stream/
      app_stream_provider.dart
      app_stream_builder.dart
```
