# Setting Feature Provider 骨架设计

日期：2026-07-14  
状态：已确认（方案 1）

## 背景

`features/setting` 仅有 `view/` + `widget/`，端口相关校验、检测、持久化编排、脏表单与重绑逻辑堆积在 `SettingPortSection`，不符合项目 feature 分层（`data/` + `provider/` + `view/` + `widget/`）。

## 目标

1. 搭完整 setting 骨架（`provider/` + 必要时 `data/`）。
2. 将端口逻辑作为第一块迁入 `SettingProvider`；后续设置项沿用同一 Provider。
3. **不改变**现有用户可见行为（OpenSpec `share-port-settings` / `share-port-guard` 语义保持）。

## 非目标

- 不合并或删除全局 `SharePortController`。
- 不拆多个 Setting*Provider。
- 不把 `TextEditingController` / `FocusNode` / `ExpandAbleController` 放进 Provider。
- 不引入 App 重启弹窗（保存后仍进程内重绑）。

## 决策摘要

| 决策 | 选择 |
|------|------|
| 范围 | 完整 setting 骨架，端口先迁入 |
| 全局配置 | 保留 `SharePortController`（启动监听、Home 守卫仍读它） |
| Provider 粒度 | 单一 `SettingProvider` |
| 落地方式 | Provider 管状态与编排；Widget 管 Flutter 控件生命周期 |

## 架构与目录

```
lib/features/setting/
├── data/
│   └── setting_port_messages.dart   # 端口相关文案常量
├── provider/
│   └── setting_provide.dart         # SettingProvider + settingProvider
├── view/
│   ├── setting_page.dart
│   ├── setting_page_mixin.dart
│   ├── setting_page_app.dart
│   └── setting_page_pc.dart
└── widget/
    └── setting_port_section.dart    # 展示 + 控件生命周期 + 回调
```

### 职责边界

| 层 | 职责 |
|----|------|
| `SharePortController` | 全局 prefs、`useCustomPort` / `customPort`、聚焦与导航信号 |
| `SettingProvider` | 设置页 UI 状态与编排：展开、草稿、脏标记、错误/检测、重绑中；toggle / 检测 / 保存 → 写回 Controller → `restartListening` → `homeProvider.rebindAfterServerRestart` |
| `SettingPortSection` | `TextEditingController` / `FocusNode` / `ExpandAbleController`；`ref.watch(settingProvider)`；SnackBar / Focus 在 UI 层执行 |
| `data/` | 静态文案（校验、检测、SnackBar），避免硬编码散落 |

## 状态字段与方法

### 状态

- `expanded` — 是否展开端口区（与开关同步）
- `draftPortText` — 输入草稿
- `fieldError` / `checkMessage` / `checkOk` / `checking` / `rebinding`
- `isDirty` — `draftPortText.trim()` ≠ `SharePortController.customPort?.toString() ?? ''`
- `isEnabled(isSharing)` — `!isSharing && !rebinding`

### 方法

- `syncFromController()` — 从 `SharePortController` 对齐展开与草稿（输入框有焦点时不覆盖草稿）
- `onDraftChanged(String)` — 更新草稿、清检测结果、刷新 dirty
- `onToggle(bool enabled)` — 关：收起 + `saveSystemAllocation` + 按需重绑；开：展开，已有合法端口则保存并重绑，否则设 `fieldError`
- `checkPort()` — 范围校验 → `PortUtil.isPortFree`（含当前监听口 owned 例外）→ 更新 `checkMessage`
- `savePort()` — 校验 → `saveCustomPort` → 按需重绑；成功清 error/check
- `handleFocusRequest(requestId)` — 消费聚焦信号时设 `expanded = true`，返回是否需要 UI `requestFocus`
- `persistAndRebind`（私有）— persist → `restartListening` → `homeProvider.rebind`；结果以枚举返回，不持有 `BuildContext`

### 结果枚举（示意）

`SettingPortApplyResult`：`noop` / `saved` / `rebindOk` / `rebindFailed`  
Widget 据此弹出 SnackBar（成功：「端口已生效」；失败：「配置已保存，但服务重绑失败，请稍后重试」）。

## 数据流与页面接入

```
SharePortController (DI 全局)
        ↑ 读 / 写 prefs
SettingProvider (Riverpod ChangeNotifierProvider)
        ↑ ref.watch / 方法调用
SettingPage → SettingPortSection
        ↓ SnackBar / Focus
UI 副作用
```

### 接入约定

- `SettingPortSection` 使用 `ConsumerStatefulWidget`（或等价 `Consumer`），`ref.watch(settingProvider)`。
- `isSharing` 仍由父级（Tab/Home）下传，避免 section 强绑 Home 结构。
- Provider 在构造或首次绑定时 `addListener` `SharePortController`；`focusPortRequestId` 变化时通知 UI 聚焦。
- 顶层：`final settingProvider = ChangeNotifierProvider<SettingProvider>((ref) => SettingProvider(...));`

### 错误处理

- 非法端口 → 只设 `fieldError`，不写 prefs。
- 检测占用 → `checkMessage`，不自动保存。
- 重绑失败 → prefs 已写，SnackBar 提示重绑失败。

## 行为不变清单

- 脏表单才显示「保存」。
- 分享中禁用开关、输入、检测、保存。
- 关闭自定义 → 系统分配并立即重绑。
- 保存合法自定义端口后立即重绑，不弹 App 重启对话框。
- 启动分享时端口占用仍弹对话框并跳转设置聚焦。

## 验证

- `flutter analyze` 相关改动无新增告警。
- 手动核对：脏表单显示保存；开关与保存重绑；分享中禁用；聚焦跳转；亮暗主题颜色正常。

## 实现顺序（概要）

1. 新增 `data/setting_port_messages.dart` 与 `provider/setting_provide.dart`。
2. 将 `SettingPortSection` 中业务逻辑迁入 Provider，Widget 改为展示 + 同步。
3. `SettingPage` 接入 `settingProvider`（若需要）。
4. `flutter analyze` + 手动冒烟。
