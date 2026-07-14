## Purpose

全局自定义端口配置、开启分享前占用守卫，以及保存后进程内重绑分享服务监听端口。

## Requirements

### Requirement: Global share port configuration via DI controller

系统 SHALL 提供全局 `SharePortController`（或等价 `AppController`），并通过 `DI.put(..., permanent: true)` 注册，供设置页与分享启动流读取。Controller MUST 持久化「是否自定义端口」与「自定义端口值」，进程重启后恢复。

#### Scenario: Controller available app-wide

- **WHEN** 应用完成初始化
- **THEN** 任意层可通过 DI 取得同一 `SharePortController` 实例

#### Scenario: Preferences survive app process restart

- **WHEN** 用户开启自定义端口并保存合法端口后重新打开应用
- **THEN** Controller 恢复为相同开关状态与端口值

### Requirement: Share start uses system or custom port mode

开启分享前，系统 MUST 读取全局端口配置：自定义关闭时 SHALL 保持现有系统分配逻辑；自定义开启时 MUST 先校验端口范围，再调用 `PortUtil` 检测空闲。

#### Scenario: System allocation unchanged

- **WHEN** 自定义端口开关关闭且用户开始分享
- **THEN** 系统不因本特性改变既有系统分配端口启动路径

#### Scenario: Custom port free allows start

- **WHEN** 自定义端口开启、端口合法且空闲，用户开始分享
- **THEN** 系统继续启动分享会话（服务监听端口与配置一致）

#### Scenario: Invalid custom port blocks start

- **WHEN** 自定义端口开启但端口非法，用户开始分享
- **THEN** 系统不启动分享，并向用户提示修正端口

### Requirement: Occupied custom port aborts and navigates to settings

当自定义端口被占用时，系统 MUST 终止本次分享启动，弹出对话框；用户确认后 MUST 导航到设置页，并将焦点落到端口输入表单。

#### Scenario: Occupied port shows dialog

- **WHEN** 自定义端口开启且占用检测失败，用户尝试开始分享
- **THEN** 分享不启动，并显示说明端口占用的确认对话框

#### Scenario: Confirm navigates and focuses port field

- **WHEN** 用户在占用对话框中确认
- **THEN** 应用切换到设置 Tab，端口输入框获得焦点以便修改

### Requirement: Custom port applied via in-process server rebind

自定义端口配置生效时，内嵌/子进程分享服务 MUST 以该端口监听（而非仅改展示 URL）。未分享状态下保存生效配置后，系统 MUST 在当前进程内停止分享服务并以新配置重新启动监听；MUST NOT 要求用户重启整个应用。

#### Scenario: Cold start with custom port

- **WHEN** 应用启动时自定义端口已开启且端口合法
- **THEN** `ShareServerHost` 以该端口启动，不以 `0` 系统分配

#### Scenario: Save rebinds listen port without app restart

- **WHEN** 当前未分享，用户将自定义端口配置改为另一合法值并保存
- **THEN** 配置写入持久化，分享服务 stop 后按新端口重新监听，health/`ws_url` 反映新端口，且不弹出「请重启应用」类对话框

#### Scenario: Toggle off rebinds to system allocation

- **WHEN** 当前未分享，用户关闭自定义端口并保存生效
- **THEN** 服务以系统分配端口（`0`）重新监听，无需重启应用
