## 1. Port util & constants

- [x] 1.1 在 `PortUtil` 实现 `isValidCustomPort`（`11285…65535`）与 `isPortFree`（`ServerSocket.bind` + `anyIPv4`，覆盖 Android/macOS/Windows/Linux）
- [x] 1.2 抽出共享常量 `kMinCustomSharePort` / `kMaxCustomSharePort`（util 与 UI/Controller 共用）

## 2. Global SharePortController + persistence

- [x] 2.1 新增 `AppKeys`：自定义开关 bool、自定义端口 int
- [x] 2.2 实现 `SharePortController`（`AppController`）：加载/保存 prefs、开关与端口 setter、校验、请求聚焦端口的信号
- [x] 2.3 在 `main.dart` `DI.put(SharePortController(), permanent: true)`，确保位于 `PrefsUtil.init` 之后可用

## 3. Share server listens configured port (in-process rebind)

- [x] 3.1 调整 `ensureStarted`：读 Controller，自定义合法则用该端口，否则 `systemAllocatedPort = 0`
- [x] 3.2 `ShareServerRuntime`/`Host` 提供 restartListening：stop → ensureStarted；设置保存后调用（不弹 App 重启对话框）
- [x] 3.3 占用预检：若目标端口等于当前进程已监听端口，视为可用；否则按 `PortUtil` 常规检测
- [x] 3.4 `ShareSessionService` + `HomeProvider` 在重绑后 disconnect 并更换 base URI / 刷新 health
- [x] 3.5 去掉「配置口 ≠ 当前监听口则禁止分享」的 pending-restart 守卫；保存成功用 SnackBar 提示已生效

## 4. Settings UI

- [x] 4.1 设置页替换占位：自定义端口 `Switch` + `ExpandAbleInherited`/`ExpandAbleController` + `CrossFade` 展开端口区
- [x] 4.2 端口 `TextField`（整数限制）+ 右侧检测按钮；调用 `PortUtil` 并反馈空闲/占用/非法
- [x] 4.3 绑定 `SharePortController`；`isSharing` 为 true 时禁用开关、输入与检测
- [x] 4.4 控件颜色使用传入 `ColorValue`，随主题切换更新

## 5. Share-start guard & navigation focus

- [x] 5.1 在 `HomeProvider._startSharing`（或等价入口）接入守卫：系统分配直通；自定义则范围校验 + `isPortFree`
- [x] 5.2 占用时中止启动、弹确认对话框；确认后切到设置 Tab 并聚焦端口输入框
- [x] 5.3 Tab 层提供可调用的切 Tab + 设置页 focus 协作（Inherited/notifier/`GlobalKey`，按最小改动选型）

## 6. Verification

- [x] 6.1 `flutter analyze` 相关改动无新增告警
- [ ] 6.2 手动核对：关开关系统分配并立即重绑；开开关合法空闲可分享；保存后无重启弹窗且端口已变；占用弹窗跳转聚焦；分享中控件禁用；亮暗主题颜色正常
