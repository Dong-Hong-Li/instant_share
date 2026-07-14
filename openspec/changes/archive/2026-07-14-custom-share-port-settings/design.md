## Context

分享服务由 `ShareServerHost.ensureStarted` 启动。Go `StartServer` 对已运行实例幂等，但 **`StopServer` 后可再以新端口 `StartServer`**，因此换端口不必重启整个 App。设置页已有自定义端口 UI；此前错误地选择了「持久化 + 引导重启 App」。

## Goals / Non-Goals

**Goals:**

- 设置页可开关自定义端口，展开后填写 `11285–65535`，支持手动空闲检测
- 配置全局 Controller + DI + Prefs
- **未分享时保存配置 → 进程内 stop + 按新配置 start，立即生效**
- 开启分享前：系统分配不变；自定义则占用检测失败则中止并引导到设置页聚焦
- 分享中禁用两项设置；UI 跟 `ColorValue` / 主题

**Non-Goals:**

- 分享进行中热切换监听端口
- 整 App 自动/手动重启作为换端口手段
- Web / iOS；改 Go WS 协议帧

## Decisions

### 1. 全局 `SharePortController` + DI

- 同前：`AppController` + `DI.put` + `PrefsUtil` / `AppKeys`。

### 2. 端口生效：进程内 stop → start（取代 App 重启）

- **选择**：
  1. 持久化配置成功后，若当前**未分享**，调用 `ShareServerHost`：`stop()` → 短 settle → `ensureStarted()`（内部 `StartServer(resolveShareServerListenPort())`）。
  2. 随后 `ShareSessionService` disconnect + 换 `serverBaseUri`，`HomeProvider` 刷新 health/端口展示。
  3. 成功用轻量反馈（SnackBar「端口已生效」）；失败提示错误且配置可仍已写入 Prefs（或按实现回滚——倾向保留 Prefs，提示重试重绑）。
- **否决**：整 App 重启对话框（体验差；Go 已支持 Stop+Start）。

### 3. Runtime API

- 在 `ShareServerRuntime` 增加 `restartListening()`（或 Host 封装）：幂等 stop + ensureStarted。
- Embedded / Process 两套实现均走同一语义。

### 4. `PortUtil` / 设置 UI / 开启前守卫

- 同前；去掉「当前监听口 ≠ 配置口则禁止分享」的 pending-restart 守卫（重绑后应一致）。
- 预检：目标口等于当前监听口视为可用（自占用）。

### 5. 校验常量

```text
kMinCustomSharePort = 11285
kMaxCustomSharePort = 65535
systemAllocatedPort = 0
```

## Risks / Trade-offs

- **[Risk] stop/start 竞态与旧 WS** → Mitigation：先 disconnect session，再 stop/start，再 rebind URI。
- **[Risk] 新端口 Listen 失败** → Mitigation：表面错误；允许用户改端口重试。
- **[Risk] Process 运行时重启子进程较慢** → Mitigation：可接受；UI 可短暂 busy。
- **[Trade-off] Prefs 已写但 rebind 失败** → 保留 Prefs，下次冷启动仍按新配置；提示用户重试。

## Migration Plan

1. 默认 `useCustomPort = false`。
2. 移除设置保存路径上的 App 重启对话框调用。
3. 回滚：去掉 rebind，恢复恒 `port=0` 即可。

## Open Questions

- rebind 失败时是否自动回滚 Prefs——默认不回滚，实现时 SnackBar 提示即可。
