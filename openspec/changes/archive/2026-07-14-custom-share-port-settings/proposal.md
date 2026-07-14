## Why

局域网分享目前始终由系统分配空闲端口，用户无法在防火墙白名单、固定二维码/书签等场景下锁定端口。设置页需补齐「自定义端口」能力，并在开启分享前拦截已被占用的端口。

## What Changes

- 设置页新增两项：**自定义端口开关**、**端口输入框**（开关开启时用 `CrossFade` + `ExpandAbleController` 展开）
- 端口校验范围：**整数且 `11285 ≤ port ≤ 65535`**
- 新增 `PortUtil`：在 Android / macOS / Windows / Linux 上通过 `dart:io` 试绑定检测端口是否空闲
- 端口输入框右侧增加「检测空闲」按钮，调用 `PortUtil` 并给出结果反馈
- 自定义端口开关与端口值由**全局 Controller + `DI.put`** 持有并持久化
- 保存生效配置后：**进程内 `StopServer` + 再按新端口 `StartServer`**，立即重绑监听口；**不再**弹窗要求重启整个 App
- 开启分享前：系统分配走现有逻辑；自定义模式先做占用检测——若占用则中止启动，弹对话框，确认后跳转设置页并聚焦端口输入框
- 分享进行中禁用上述两个控件；控件配色跟随 `ColorValue` / 全局主题

## Capabilities

### New Capabilities

- `share-port-settings`: 设置页自定义端口开关/输入/空闲检测、分享中禁用、主题适配
- `share-port-guard`: 全局端口配置 Controller、开启分享前占用校验与导航聚焦、保存后进程内重绑

### Modified Capabilities

- （无既有主库 `openspec/specs/`；本变更内规格已按进程内重绑修订）

## Impact

- **UI**：`lib/features/setting/**`；Tab 导航支持跳到设置并聚焦
- **核心**：`PortUtil`、`SharePortController`、Prefs/`AppKeys`；`ShareServerRuntime` 增加 restart/rebind
- **分享流**：`HomeProvider` / `ShareSessionService` 在端口变更后 disconnect 并换 base URI
- **平台**：桌面 + Android；Web 不在范围
- **依赖**：无新第三方包；Go `StopServer` + `StartServer` 已支持换端口
