# Mutual Share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 Host 审批多 Peer 入房、App 内聚合文件目录、PC Web `/share` 展示房间 catalog、下载直连文件所有者本机；Host 顶栏保持文章/文件双模式。

**Architecture:** Host Go 新增 `RoomService` + WS `peer` 角色（配对 / offer / notify）；文件字节不落 Host。Flutter 本机仍用 `ShareSessionService`（admin），新增 `RemoteRoomClient` + `MutualShareProvider`；右上角「+」发起配对；现有「链接」Tab（`LinkPage`）承载待审批/成员列表；仅 Peer 入房后顶栏切「共享文件」。

**Tech Stack:** Go（`instant_share_server`）+ Flutter/Riverpod（`ChangeNotifierProvider`）+ 现有 gorilla websocket 帧协议。

**Specs:** [requirements.md](./requirements.md) · [architecture.md](./architecture.md)

## Global Constraints

- Peer **禁止**以 `admin` 控制 Host；admin 仅本机 Flutter ↔ 本机服务。
- **禁止**默认把 Peer 文件上传/中转到 Host 磁盘；`share.offer` 仅元数据。
- **不做**下载鉴权 / token。
- PC Web `/share` 在房间 catalog 非空时展示聚合目录（见 [web-room-catalog-design](../superpowers/specs/2026-07-21-web-room-catalog-design.md)）；无 catalog 时仍只读本机 `ShareStatus`。
- Host 顶栏保持 `[分享文章 | 分享文件]`；仅 Peer `joinedRoom` 切 `[共享文件]`。
- 支持**多 Peer**；配对等待 **60s**。
- 包名/import 前缀：`instant_share`（Flutter）/ `instant_share/server/...`（Go）。
- 最小改动；不手改无关生成文件。
- 重复 pending：同一 `device_id` **合并**（刷新 `expires_at` / `peer_base_url`，不新建第二条）。

---

## File map（锁定边界）

### Go（新建 / 修改）

| 路径 | 职责 |
|------|------|
| `instant_share_server/internal/model/room_types.go` | PendingRequest / Member / SharedEntry / Room 快照 DTO |
| `instant_share_server/internal/service/room.go` | 配对、多成员、catalog 聚合、revision |
| `instant_share_server/internal/service/room_test.go` | RoomService 单测 |
| `instant_share_server/internal/infrastructure/websocket/frame.go` | 增加 `RolePeer` |
| `instant_share_server/internal/infrastructure/websocket/client.go` | `DefaultAuth` 接受 `peer` |
| `instant_share_server/internal/handler/ws_room.go` | pairing / offer / notify / admin 审批帧 |
| `instant_share_server/internal/handler/ws_admin.go` | `share.stop` 时解散 Room；`share.sync` 后刷新 host 目录条目 |
| `instant_share_server/internal/app/app.go` | 装配 RoomService + 注册 ws_room |

### Flutter（新建 / 修改）

| 路径 | 职责 |
|------|------|
| `lib/infrastructure/websocket/room_ws_models.dart` | 房间协议 DTO |
| `lib/infrastructure/websocket/remote_room_client.dart` | 连 Host WS：pairing / offer / notify |
| `lib/features/mutual_share/provider/mutual_share_provide.dart` | 房间 UI 状态机 |
| `lib/features/mutual_share/widget/connect_peer_dialog.dart` | 右上角「+」弹窗 |
| `lib/features/mutual_share/widget/pairing_waiting_overlay.dart` | 60s 等待态 |
| `lib/features/link/...` | 待审批 / 已连接成员 UI（替换占位） |
| `lib/features/home/view/home_share_page_*.dart` | 右上角「+」、Peer 顶栏/背景 |
| `lib/features/home/provider/provider.dart` | 本机 sync 后触发 host 侧 catalog 刷新编排（或经 MutualShareProvider） |

**Web catalog（Task 9+，见 superpowers plan）：** `PublicHandler` / viewer `share.status` 经 `buildPublicShareStatus` 合并房间 catalog；Peer 镜像经 admin `room.public_catalog.sync`。

---

### Task 1: Go 房间模型 + RoomService（配对 / 多成员 / catalog）

**Files:**
- Create: `instant_share_server/internal/model/room_types.go`
- Create: `instant_share_server/internal/service/room.go`
- Create: `instant_share_server/internal/service/room_test.go`

**Interfaces:**
- Produces:
  - `type RoomService struct`
  - `func NewRoomService() *RoomService`
  - `func (s *RoomService) EnsureRoom(hostDeviceID, hostBaseURL, sessionID string)`
  - `func (s *RoomService) RequestPairing(deviceID, displayName, peerBaseURL string) (PendingRequest, error)` — 同 device 合并；TTL 60s
  - `func (s *RoomService) Approve(deviceID string) (Member, error)`
  - `func (s *RoomService) Reject(deviceID string) error`
  - `func (s *RoomService) SweepExpired() []string` — 返回超时 device_id 列表
  - `func (s *RoomService) SetOwnerFiles(ownerID, displayName, baseURL string, files []SharedFileMeta) (catalog []SharedEntry, revision int)`
  - `func (s *RoomService) Catalog() (entries []SharedEntry, revision int)`
  - `func (s *RoomService) Members() []Member`
  - `func (s *RoomService) Pending() []PendingRequest`
  - `func (s *RoomService) Close()` — 清空房间
  - `func (s *RoomService) IsAuthorizedPeer(deviceID string) bool`

- [ ] **Step 1: 写入 `room_types.go`**

```go
package model

import "time"

type SharedFileMeta struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Size         int64  `json:"size"`
	DownloadPath string `json:"download_path"`
}

type SharedEntry struct {
	ID                string `json:"id"`
	Name              string `json:"name"`
	Size              int64  `json:"size"`
	OwnerID           string `json:"owner_id"`
	OwnerDisplayName  string `json:"owner_display_name,omitempty"`
	BaseURL           string `json:"base_url"`
	DownloadPath      string `json:"download_path"`
}

type PendingRequest struct {
	DeviceID      string    `json:"device_id"`
	DisplayName   string    `json:"display_name"`
	PeerBaseURL   string    `json:"peer_base_url"`
	RequestedAt   time.Time `json:"requested_at"`
	ExpiresAt     time.Time `json:"expires_at"`
}

type Member struct {
	DeviceID    string `json:"device_id"`
	DisplayName string `json:"display_name"`
	PeerBaseURL string `json:"peer_base_url"`
}
```

- [ ] **Step 2: 写失败单测（配对合并、批准、超时、SetOwnerFiles 聚合）**

`room_test.go` 至少覆盖：
1. `RequestPairing` 同 `device_id` 两次 → pending 长度为 1，且 `ExpiresAt` 刷新  
2. `Approve` 后出现在 `Members`，从 `Pending` 移除  
3. `SweepExpired` 在过期后移除 pending  
4. 两个 owner `SetOwnerFiles` 后 `Catalog` 含两边条目，`revision` 递增  
5. `Close` 后 catalog/members/pending 为空  

- [ ] **Step 3: 实现 `RoomService`（内存 + `sync.RWMutex`）**

关键规则：
- 无房间时 `RequestPairing` 返回明确错误（Host 未开分享）
- `Approve` 要求仍在 pending 且未过期
- `SetOwnerFiles`：替换该 `ownerID` 名下全部条目后重算聚合列表

- [ ] **Step 4: 跑测**

```bash
cd instant_share_server && go test ./internal/service/ -count=1
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add instant_share_server/internal/model/room_types.go \
  instant_share_server/internal/service/room.go \
  instant_share_server/internal/service/room_test.go
git commit -m "$(cat <<'EOF'
feat(server): add RoomService for mutual-share pairing and catalog

EOF
)"
```

---

### Task 2: WS `peer` 角色 + 房间帧处理

**Files:**
- Modify: `instant_share_server/internal/infrastructure/websocket/frame.go`
- Modify: `instant_share_server/internal/infrastructure/websocket/client.go`（`DefaultAuth`）
- Create: `instant_share_server/internal/handler/ws_room.go`
- Modify: `instant_share_server/internal/handler/ws_admin.go`
- Modify: `instant_share_server/internal/app/app.go`

**Interfaces:**
- Consumes: Task 1 `RoomService`
- Produces WS types（与现有 Packet 风格一致）:
  - `pairing.request` / `pairing.request_ack`
  - `pairing.approve` / `pairing.reject` / `pairing.timeout`（推给申请方）
  - `pairing.decide`（admin → Host：`{ "device_id", "approve": true|false }`）
  - `share.offer` / `share.offer_ack`
  - `room.notify`（`event`: `catalog_updated` | `pending_updated` | `room_closed`）
  - `room.snapshot`（authorized peer 可拉全量：pending 不给 peer；给 catalog + members）

连接策略（写死）：
1. Peer `auth`：`role=peer` → 连接建立，默认 `authorized=false`
2. 仅允许发 `pairing.request`；成功后进入 pending
3. Host admin 发 `pairing.decide` → RoomService Approve/Reject → 推 `pairing.approve|reject` 给该 peer 连接
4. Approve 后同连接 `authorized=true`，允许 `share.offer` / `room.snapshot`，并收 `room.notify`
5. 后台 goroutine 每 5s `SweepExpired`，对超时 device 推 `pairing.timeout`

- [ ] **Step 1: `frame.go` 增加 `RolePeer = "peer"`；`DefaultAuth` 接受 peer（uid=`device_id`）**

- [ ] **Step 2: 实现 `WSRoomHandler` 并在 `app.go` 注入 `RoomService`**

`share.start` 成功后：`room.EnsureRoom(hostDeviceID, hostBaseURL, sessionID)`，并把当前本机 files 写入 catalog（owner=host）。  
`share.stop` 成功后：`room.Close()` + 向所有 peer 广播 `room.notify{event:room_closed}` 并断开 peer 连接（或标记后关闭）。

`share.sync` / 文件变更后：更新 host owner 的 `SetOwnerFiles`，广播 `catalog_updated`。

权限：
- `pairing.decide`：仅 `admin`
- `pairing.request`：仅 `peer` 且未授权或可刷新 pending
- `share.offer`：仅 `peer` 且 `authorized`；`owner_id` 必须等于 `conn` 的 device_id；`base_url` 必须等于成员登记的 `peer_base_url`
- peer 调用 `share.start|stop|sync`：保持现有 403

- [ ] **Step 3: 手工/集成冒烟（可用 `websocat` 或临时 Go 小测）**

验证：
1. peer `share.stop` → 403  
2. pairing 同意后能收到 `pairing.approve`  
3. offer 后 admin 与 peer 均收到 `catalog_updated`  
4. `share.stop` → peers 收到 `room_closed`

- [ ] **Step 4: `go test ./...` 与 `go build ./cmd/server`**

```bash
cd instant_share_server && go test ./... -count=1 && go build -o /tmp/instant_share_server ./cmd/server
```

Expected: PASS / 构建成功

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(server): wire peer WS pairing and room catalog notify

EOF
)"
```

---

### Task 3: Flutter 房间协议模型 + RemoteRoomClient

**Files:**
- Create: `lib/infrastructure/websocket/room_ws_models.dart`
- Create: `lib/infrastructure/websocket/remote_room_client.dart`

**Interfaces:**
- Produces:
  - `class RemoteRoomClient`
  - `Future<void> connect({required Uri hostWsUrl, required String deviceId, required String displayName, required Uri peerBaseUrl})`
  - `Future<void> requestPairing()`
  - `Future<void> offerFiles(List<RoomFileOffer> files)`
  - `Future<RoomSnapshot> fetchSnapshot()`
  - `Stream<RoomNotifyEvent> get notifies`
  - `Stream<PairingOutcome> get pairingOutcomes` — approve/reject/timeout
  - `Future<void> disconnect()`
  - DTO: `RoomFileOffer`, `SharedEntryDto`, `RoomSnapshot`, `PairingOutcome`, `RoomNotifyEvent`

- [ ] **Step 1: 定义 DTO（字段名与 Go JSON tag 对齐）**

- [ ] **Step 2: 实现 `RemoteRoomClient`**

复用现有 WS 读写模式（参考 `ShareWsAdminClient`）：首帧 auth `role=peer` → 再发业务帧；按 `type` 分发。  
`hostWsUrl` 由用户输入的 IP/端口拼：`ws://$ip:$port/ws`（注意与本机 admin 的 `127.0.0.1` 分离）。

- [ ] **Step 3: 自检连接自己**

在 client 或上层调用前：若目标 host IP 属于本机 `local_ips`（可从本机 health 获取），抛出/返回「不能连接本机」。

- [ ] **Step 4: `dart analyze` 相关文件无 error**

```bash
dart analyze lib/infrastructure/websocket/room_ws_models.dart \
  lib/infrastructure/websocket/remote_room_client.dart
```

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(app): add RemoteRoomClient for host room WS

EOF
)"
```

---

### Task 4: MutualShareProvider + 右上角「+」配对 UI

**Files:**
- Create: `lib/features/mutual_share/provider/mutual_share_provide.dart`
- Create: `lib/features/mutual_share/widget/connect_peer_dialog.dart`
- Create: `lib/features/mutual_share/widget/pairing_waiting_overlay.dart`
- Modify: `lib/features/home/view/home_share_page_pc.dart`
- Modify: `lib/features/home/view/home_share_page_app.dart`（若移动端同样需要入口则同步；否则 PC 优先）

**Interfaces:**
- Produces `MutualShareProvider`（`ChangeNotifier`）状态：
  - `enum MutualSharePhase { idle, pairingPending, joinedRoom }`
  - `phase`, `countdownSeconds`, `errorMessage`
  - `catalog`, `remoteHostBaseUrl`
  - `Future<void> startPairing({required String hostIp, int? port})`
  - `Future<void> cancelPairing()`
  - `Future<void> leaveRoom()`
- UI：右上角「+」打开 `ConnectPeerDialog`；pending 时展示 60s 倒计时，可取消

- [ ] **Step 1: 实现 Provider 状态机**

`idle → pairingPending(60s timer) → joinedRoom | idle(reject/timeout/cancel)`  
加入成功后缓存 catalog；监听 `room_closed` → `idle`。

- [ ] **Step 2: 实现弹窗与等待 UI**

- [ ] **Step 3: 挂到 Home 右上角**

在 `HomeSharePageShell.topRight` 组合：现有 `HomeServerUrlHint`（若仍需要）与新的「+」按钮——**「+」为连接入口**（需求确认）。若空间冲突：`Row` 排列「+」与问号，**「+」在最右侧或按设计稿优先**。

注意：不要改底部摘要栏加号的「添加文件」语义。

- [ ] **Step 4: 手动验证**

1. 点右上角「+」→ 输入非法 IP → 错误提示  
2. 输入可达 Host → 进入倒计时  
3. 取消 → 回到 idle  

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(app): add connect-peer entry and pairing waiting UI

EOF
)"
```

---

### Task 5: 链接 Tab — Host 审批与多成员列表

**Files:**
- Modify: `lib/features/link/view/link_page.dart` 及 mixin/pc/app
- Create: `lib/features/link/provider/link_provide.dart`（或复用 `MutualShareProvider` 的 host 侧 API）
- Modify: 本机 admin WS client（扩展 `pairing.decide` / 收 `pending_updated`）  
  - 优先扩展 `lib/infrastructure/websocket/share_ws_admin_client.dart`  
  - 或新建 `lib/infrastructure/websocket/host_room_admin_api.dart` 挂在同一 admin 连接上

**Interfaces:**
- Host 侧：
  - `Future<void> decidePairing(String deviceId, {required bool approve})`
  - `List<PendingRequestDto> pending`
  - `List<MemberDto> members`
- 「链接」Tab 仅在 `home.isSharing` 时可见（现有 `TabSidebarItem.visibleTabs` 已如此）

- [ ] **Step 1: admin 连接增加房间相关帧收发**

- [ ] **Step 2: 替换 `LinkPage` 占位为列表 UI**

分区：
1. 待审批：显示名 / IP(from peer_base_url) / 倒计时或申请时间 → 同意 / 拒绝  
2. 已连接：成员列表  

- [ ] **Step 3: 双机验证配对全流程**

A 开分享 → B「+」连 A → A 链接 Tab 同意 → B `joinedRoom`

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(app): implement link tab pending approval for peers

EOF
)"
```

---

### Task 6: share.offer 编排 + App 房间目录 UI

**Files:**
- Modify: `lib/features/mutual_share/provider/mutual_share_provide.dart`
- Modify: `lib/features/home/provider/provider.dart`（本机文件变更时）
- Create: `lib/features/mutual_share/widget/room_catalog_list.dart`
- Modify: Home 文件区：Peer `joinedRoom` 时展示房间 catalog（可下载）

**行为：**
1. Peer 入房后：将本机当前分享文件（若已 start）或用户在 Peer 侧选中并 sync 到本机 `ShareService` 的文件，通过 `RemoteRoomClient.offerFiles` 全量快照上报  
2. Host：本机 `share.sync` 成功后服务端已更新 catalog（Task 2）；App 收 `catalog_updated` 刷新  
3. 列表项下载：`Uri.parse(entry.baseUrl).resolve(entry.downloadPath)`，**禁止**拼到本机 base  
4. Web 展示 room catalog：`PublicHandler` 合并 Host `RoomService` 或 Peer 镜像；见 superpowers web-room-catalog 计划

- [ ] **Step 1: offer 编排（全量快照）**

Peer 本机文件列表变化 → 先完成本机 `ShareSessionService.syncShare` → 再 `offerFiles`。

- [ ] **Step 2: 房间目录列表组件 + 下载**

使用现有下载/打开方式或 `url_launcher`/HTTP 存文件（与项目现有文件下载模式一致）。

- [ ] **Step 3: 验证**

1. B offer 后 A/B App 均见条目  
2. 下载 B 文件请求打到 B 的 IP（代理/日志确认）  
3. 浏览器打开 A 的 `/share` **能看到** B 的文件，下载打到 B 的 IP；打开 B 的 `/share` **能看到** A 的文件，下载打到 A 的 IP

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(app): sync room catalog via share.offer with web aggregated catalog

EOF
)"
```

---

### Task 7: Peer 入房视觉（分享色 + 顶栏「共享文件」）

**Files:**
- Modify: `lib/features/home/view/home_share_page_pc.dart`（及 app 若需要）
- Modify: 顶栏分段控件所在 widget（定位现有「分享文章 / 分享文件」组件）
- 可能修改: `lib/resource/color/home_palette.dart`（若需独立 joined 色则最小增加 token）

**行为：**
- `MutualSharePhase.joinedRoom`：
  - 背景切分享色
  - 顶栏动画为单一「共享文件」（不可再切到文章）
- Host（未 joined 远端）：顶栏**不变**
- `leaveRoom` / `room_closed`：恢复原顶栏与背景

- [ ] **Step 1: 根据 `mutualShareProvider.phase` 驱动顶栏/背景**

- [ ] **Step 2: 确认 Host 开分享且有 Peer 时，Host 自己顶栏仍为双模式**

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(app): peer joined-room chrome with shared-files header

EOF
)"
```

---

### Task 8: 异常路径、多 Peer 联调与收尾

**Files:**
- 按缺陷修改 Task 1–7 相关文件
- Modify: `docs/mutual-share/requirements.md` / `architecture.md` 页脚状态（可选：标「实现中/已完成」）
- Modify: `instant_share_server/README.md` — 增补 peer/房间协议一小段（保持简短）

**验收清单（对照需求 §9 / 架构 §11）：**

- [ ] 配对：同意 / 拒绝 / 60s 超时 / 取消  
- [ ] 多 Peer：两台 Peer 同时在房，目录互相可见（App）  
- [ ] peer 调 `share.stop` → 403  
- [ ] 大文件：仅 offer 元数据，Host 磁盘无明显增长  
- [ ] 下载各打所有者  
- [ ] Host 顶栏不变；Peer 顶栏「共享文件」  
- [ ] PC Web `/share`：A/B 链接均见聚合文件；下载各打所有者；离房后对方文件消失
- [ ] Host `share.stop` → Peer 回到 idle  
- [ ] 连接自己被拒绝  
- [ ] `flutter analyze` + `cd instant_share_server && go test ./...` 通过  

- [ ] **Step 最终 Commit（若有文档/README 变更）**

```bash
git commit -m "$(cat <<'EOF'
docs: note mutual-share room peer protocol in server README

EOF
)"
```

---

## Spec coverage（自检）

| 需求要点 | Task |
|----------|------|
| 右上角「+」连 IP | 4 |
| 60s 审批 / 链接 Tab | 2, 5 |
| 多 Peer | 1, 2, 8 |
| peer 非 admin | 2 |
| 本机链接下载 / 无中转 | 1, 6 |
| Host 顶栏不变 / Peer「共享文件」 | 7 |
| PC Web 聚合 catalog | 6, 8（验证）；实现见 superpowers web-room-catalog plan |
| 不做下载鉴权 | 全局约束 |

## 执行方式

计划已保存到 `docs/mutual-share/plan.md`。

**可选执行方式：**

1. **Subagent-Driven（推荐）** — 每 Task 开新子代理，Task 间复查  
2. **Inline Execution** — 本会话按 Task 连续实现并设检查点  

回复选 **1** 或 **2** 即可开始实现（或先只做 Task 1）。
