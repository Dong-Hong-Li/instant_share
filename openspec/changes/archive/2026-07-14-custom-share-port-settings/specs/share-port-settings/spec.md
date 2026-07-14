## ADDED Requirements

### Requirement: Settings exposes custom port toggle and input

设置页 SHALL 提供「自定义端口」开关；当开关开启时，SHALL 使用 `ExpandAbleController` + `CrossFade` 展开端口输入区域。端口值 MUST 为整数且满足 `11285 ≤ port ≤ 65535`。开关关闭时 SHALL 折叠输入区域，并回到系统分配端口语义。

#### Scenario: Toggle on reveals port field

- **WHEN** 用户打开自定义端口开关且当前未在分享
- **THEN** 端口输入区域以 CrossFade 展开，用户可编辑端口

#### Scenario: Invalid port rejected

- **WHEN** 用户输入非整数或不在 `11285–65535` 的值并尝试保存/生效
- **THEN** 系统拒绝该值并给出校验提示，不将非法端口写入生效配置

#### Scenario: Toggle off uses system allocation

- **WHEN** 用户关闭自定义端口开关并保存生效
- **THEN** 输入区域折叠，配置持久化为系统分配，并触发进程内服务按系统分配端口重绑

#### Scenario: Saving port settings rebinds without restart dialog

- **WHEN** 用户在未分享状态下保存生效的端口相关配置（开启并写入合法端口，或关闭自定义）
- **THEN** 系统持久化配置并进程内重绑监听端口，不弹出要求重启整个应用的对话框

### Requirement: Manual port vacancy check from settings

端口输入框右侧 SHALL 提供检测按钮；点击后 MUST 调用 `PortUtil` 在 Android / macOS / Windows / Linux 上检查端口是否空闲，并向用户反馈结果。

#### Scenario: Free port reported

- **WHEN** 用户输入合法端口并点击检测，且端口空闲
- **THEN** 系统提示端口可用

#### Scenario: Occupied port reported

- **WHEN** 用户输入合法端口并点击检测，且端口不可用/已占用
- **THEN** 系统提示端口不可用

#### Scenario: Check blocked for invalid input

- **WHEN** 当前输入不是合法自定义端口
- **THEN** 检测按钮不发起绑定探测，或先提示校验错误

### Requirement: Settings disabled while sharing

当分享会话处于进行中时，自定义端口开关与端口输入（含检测按钮）MUST 禁用，防止运行中修改。

#### Scenario: Controls disabled during active share

- **WHEN** `isSharing == true` 且用户位于设置页
- **THEN** 开关与端口输入/检测控件不可交互

#### Scenario: Controls enabled when share stopped

- **WHEN** 分享已停止
- **THEN** 上述控件恢复可编辑（在其它校验允许的前提下）

### Requirement: Settings UI follows app theme colors

设置页端口相关控件 MUST 使用应用传入的 `ColorValue`（或等价主题色），在全局主题切换后视觉颜色 SHALL 同步更新。

#### Scenario: Theme change updates settings colors

- **WHEN** 用户切换亮/暗主题后查看设置页端口区域
- **THEN** 文本、开关、输入与按钮颜色与当前主题一致
