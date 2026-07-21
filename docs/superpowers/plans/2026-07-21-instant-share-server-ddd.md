# Instant Share Server DDD 重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `instant_share_server` 一次性重构为与 bright-im 对齐的 DDD + Ports & Adapters 结构（三域 `gateway` / `share` / `room`），删除旧 `handler`/`service`/`model`/`app`，行为基本等价。

**Architecture:** `interfaces` 只做协议翻译；`application` 编排用例并声明 ports；`domain` 纯规则；`adapter/*/memory` 实现内存存储；`infrastructure/websocket` 保持无业务语义；`cmd/bootstrap` 手写装配并用回调解开 admin↔room 互持。公开页在 `interfaces/public` 编排，公开状态查询用例落在 `application/share`。

**Tech Stack:** Go 1.25（module `instant_share/server`）、标准库 `net/http`、`gorilla/websocket`、`google/uuid`；无 Wire / chi。

**Spec:** [docs/superpowers/specs/2026-07-21-instant-share-server-ddd-design.md](../specs/2026-07-21-instant-share-server-ddd-design.md)

## Global Constraints

- 依赖方向：`interfaces → application → domain`；`adapter` 实现 ports；`infrastructure` 不依赖 application/interfaces；`domain` 无 inward import。
- 路径保持：`/health`、`/api/v1/server/health`、`/share`、`/ws`。
- WS 帧类型字符串本轮**保持现网字面量**（见下方协议对照）；仅集中到 `shared/consts`。
- 公开状态优先级（行为锁）：`len(mirror)>0` → mirror；else `len(roomCatalog)>0` → room；else 本机 files。**例外：** 调用方在「权威 Host」（`len(Members())>0`）时传 `mirror=nil` 强制用房间目录。`active = share.Active || len(files)>0`；articles 始终本机。
- 下载直连所有者；本机条目相对 `download_url`，他机绝对 URL。
- `cmd/server` 与 `cmd/lib` 共用 bootstrap；`runtime` 仍负责 Listen/Serve/Shutdown。
- 开始前：若工作区有未提交的 server 行为改动，先纳入或提交，再以该行为为迁移基线（禁止回退近期 room/catalog 修复）。
- 每任务结束：`cd instant_share_server && go test ./...` 相关包通过后 commit（中文 message）。

---

## File map（锁定边界）

| 路径 | 职责 |
|------|------|
| `instant_share_server/docs/architecture-rules.md` | 本服务分层规则（精简自 bright-im） |
| `instant_share_server/config/*.go` | 原 `internal/config` |
| `instant_share_server/shared/consts/ws.go` | 角色、帧类型常量 |
| `instant_share_server/shared/errmsg/errmsg.go` | 领域/用例错误包装与稳定文案 |
| `instant_share_server/cmd/bootstrap.go` | 装配 AppDeps + Handler |
| `instant_share_server/cmd/deps.go` | `AppDeps` 结构体 |
| `instant_share_server/internal/domain/share/*.go` | Share 实体、错误、规范化规则 |
| `instant_share_server/internal/domain/room/*.go` | Room 实体、错误、TTL |
| `instant_share_server/internal/domain/gateway/*.go` | 角色值对象（若过薄可仅 consts） |
| `instant_share_server/internal/application/share/repository/*.go` | ShareStore / 只读查询所需端口 |
| `instant_share_server/internal/application/share/service/*.go` | Start/Stop/Sync + BuildPublicStatus |
| `instant_share_server/internal/application/room/repository/*.go` | RoomStore + PublicMirror 端口 |
| `instant_share_server/internal/application/room/service/*.go` | 配对/成员/catalog/镜像 + 回调 |
| `instant_share_server/internal/application/gateway/service/*.go` | Auth 用例（角色校验） |
| `instant_share_server/internal/adapter/share/memory/*.go` | 内存 ShareStore |
| `instant_share_server/internal/adapter/room/memory/*.go` | 内存 RoomStore + PublicMirror |
| `instant_share_server/internal/delivery/router.go` | 组装 `http.Handler` |
| `instant_share_server/internal/delivery/res/json.go` | 统一 JSON envelope |
| `instant_share_server/internal/interfaces/system/*.go` | health |
| `instant_share_server/internal/interfaces/gateway/*.go` | WS 升级注册 + auth |
| `instant_share_server/internal/interfaces/share/*.go` | admin WS share.* + public_catalog.* + 广播 |
| `instant_share_server/internal/interfaces/room/*.go` | pairing/room WS |
| `instant_share_server/internal/interfaces/public/*.go` | /share 静态、status、download、batch |
| `instant_share_server/internal/interfaces/request/*.go` | WS/HTTP 入参 DTO |
| `instant_share_server/internal/interfaces/response/*.go` | 出参 DTO（含 PublicShareStatus） |
| `instant_share_server/internal/infrastructure/websocket/` | 保留，import path 不变语义 |
| `instant_share_server/internal/runtime/runtime.go` | 改为依赖 bootstrap 产出的 Handler + 关闭钩子 |
| 删除 | `internal/app`、`internal/handler`、`internal/service`、`internal/model`、`internal/config` |

## 协议对照（本轮默认不改字面量）

| 常量名（Go） | 字面量 |
|---|---|
| `consts.RoleAdmin` / `RolePeer` / `RoleViewer` | `admin` / `peer` / `viewer`（与现 `websocket` 包一致） |
| `consts.TypeShareStart` … | `share.start`、`share.stop`、`share.sync`、`share.article.sync`、`share.status` 及对应 `_ack` |
| `consts.TypePairingRequest` … | `pairing.request`、`pairing.decide`、`pairing.approve`、`pairing.reject`、`pairing.timeout` |
| `consts.TypeShareOffer` / `TypeRoom*` | `share.offer`、`room.snapshot`、`room.leave`、`room.notify`、`room.public_catalog.sync`、`room.public_catalog.clear` |

Flutter `lib/infrastructure/websocket/ws_constants.dart` 仅在字面量变更时同步；默认 **Task 9 验证无需改客户端**。

---

### Task 1: 骨架、config 上移、architecture-rules、shared 常量

**Files:**
- Create: `instant_share_server/docs/architecture-rules.md`
- Create: `instant_share_server/config/config.go`（自 `internal/config/config.go` 迁）
- Create: `instant_share_server/config/websocket.go`（自 `internal/config/websocket.go` 迁）
- Create: `instant_share_server/shared/consts/ws.go`
- Create: `instant_share_server/shared/errmsg/errmsg.go`
- Modify: 所有仍引用 `instant_share/server/internal/config` 的文件 → `instant_share/server/config`（本任务只改 import，行为不变）
- Delete: `instant_share_server/internal/config/`（在 import 全部切换后）

**Interfaces:**
- Produces:
  - `package config`：`type Config struct`、`func Load() Config`、`func (c Config) Addr() string`、`DefaultWebSocketConfig()`（签名与旧包相同）
  - `package consts`：帧类型与角色字符串常量（字面量见上表）
  - `package errmsg`：先放 `var` 包装用错误消息辅助即可（后续 task 填领域错误）

- [ ] **Step 1: 写 `docs/architecture-rules.md`**

内容必须包含：分层列表、依赖方向禁止项、三域职责表、WS Client 可直接注入例外（与 spec §4 一致）。可精简抄写 bright-im `docs/architecture-rules.md` 并删掉 Redis/Raft/Wire 段落。

- [ ] **Step 2: 迁移 config 包**

将 `internal/config/*.go` 的 `package config` 文件移到根 `config/`，module 路径改为 `instant_share/server/config`。用 grep 替换：

```bash
cd instant_share_server
rg -l 'instant_share/server/internal/config' | xargs sed -i '' 's|instant_share/server/internal/config|instant_share/server/config|g'
```

- [ ] **Step 3: 添加 `shared/consts/ws.go`**

```go
package consts

const (
	RoleAdmin  = "admin"
	RolePeer   = "peer"
	RoleViewer = "viewer"

	TypeShareStart           = "share.start"
	TypeShareStartAck        = "share.start_ack"
	TypeShareStop            = "share.stop"
	TypeShareStopAck         = "share.stop_ack"
	TypeShareSync            = "share.sync"
	TypeShareSyncAck         = "share.sync_ack"
	TypeShareArticleSync     = "share.article.sync"
	TypeShareArticleSyncAck  = "share.article.sync_ack"
	TypeShareStatus          = "share.status"
	TypePairingRequest       = "pairing.request"
	TypePairingRequestAck    = "pairing.request_ack"
	TypePairingDecide        = "pairing.decide"
	TypePairingDecideAck     = "pairing.decide_ack"
	TypePairingApprove       = "pairing.approve"
	TypePairingReject        = "pairing.reject"
	TypePairingTimeout       = "pairing.timeout"
	TypeShareOffer           = "share.offer"
	TypeShareOfferAck        = "share.offer_ack"
	TypeRoomNotify           = "room.notify"
	TypeRoomSnapshot         = "room.snapshot"
	TypeRoomSnapshotAck      = "room.snapshot_ack"
	TypeRoomLeave            = "room.leave"
	TypeRoomLeaveAck         = "room.leave_ack"
	TypePublicCatalogSync    = "room.public_catalog.sync"
	TypePublicCatalogSyncAck = "room.public_catalog.sync_ack"
	TypePublicCatalogClear   = "room.public_catalog.clear"
	TypePublicCatalogClearAck = "room.public_catalog.clear_ack"
)
```

- [ ] **Step 4: 添加空 `shared/errmsg/errmsg.go`**

```go
package errmsg

// 领域与用例错误在后续 task 迁入；本文件保证包可编译。
```

- [ ] **Step 5: 验证并提交**

```bash
cd instant_share_server && go test ./...
```

Expected: PASS（与重构前同等）。

```bash
git add instant_share_server/docs instant_share_server/config instant_share_server/shared \
  instant_share_server/cmd instant_share_server/internal
git commit -m "$(cat <<'EOF'
refactor(server): 上移 config 并落地 DDD 骨架常量

EOF
)"
```

---

### Task 2: domain/share + adapter/share/memory + application/share 核心用例

**Files:**
- Create: `instant_share_server/internal/domain/share/types.go`
- Create: `instant_share_server/internal/domain/share/errors.go`
- Create: `instant_share_server/internal/domain/share/normalize.go`
- Create: `instant_share_server/internal/application/share/repository/store.go`
- Create: `instant_share_server/internal/adapter/share/memory/store.go`
- Create: `instant_share_server/internal/application/share/service/share_service.go`
- Create: `instant_share_server/internal/application/share/service/share_service_test.go`（从 `internal/service` 行为移植；若原无单测则按 Start/Stop/Sync 补最小用例）
- 暂不删除旧 `service/share.go`（Task 7 统一删）

**Interfaces:**
- Produces（包路径 `instant_share/server/internal/...`）:
  - `domain/share`：`ShareFile`、`ShareArticle`、`Status`（字段同现 `model.ShareStatus`）、`ErrShareActive`、`ErrShareNotActive`、`ErrNoFiles`、`NormalizeFiles`、`NormalizeArticles`
  - `application/share/repository`：
    ```go
    type Store interface {
        Snapshot() share.Status
        ReplaceActive(status share.Status)
        Clear()
        FileByID(id string) (share.ShareFile, bool)
    }
    ```
  - `application/share/service`：
    ```go
    type Service struct { /* store, host, port */ }
    func NewService(store repository.Store, host string, port int) *Service
    func (s *Service) Status() share.Status
    func (s *Service) HTTPBase() string
    func (s *Service) Start(files []share.ShareFile) (share.Status, error)
    func (s *Service) SyncFiles(files []share.ShareFile) (share.Status, error)
    func (s *Service) SyncArticles(articles []share.ShareArticle) (share.Status, error)
    func (s *Service) Stop() (share.Status, error)
    func (s *Service) FileByID(id string) (share.ShareFile, bool)
    ```
- Consumes: 无（新建）

- [ ] **Step 1: 写失败测试（Stop 在未 active 时返回 ErrShareNotActive）**

```go
package service_test

func TestStopWhenInactive(t *testing.T) {
    store := memory.NewStore()
    svc := service.NewService(store, "0.0.0.0", 8080)
    _, err := svc.Stop()
    if !errors.Is(err, share.ErrShareNotActive) {
        t.Fatalf("got %v", err)
    }
}
```

- [ ] **Step 2: 运行确认失败**

```bash
cd instant_share_server && go test ./internal/application/share/service/ -count=1
```

Expected: FAIL（包不存在或类型未定义）。

- [ ] **Step 3: 实现 domain + memory store + Service**

从 `internal/service/share.go` **逐逻辑迁移**（含 `normalizeFiles`/`normalizeArticles`/`resetLocked`/`uuid` session）。`Status` JSON tag 保持与现网一致，供后续 DTO 复用字段名。内存 adapter 内用 `sync.RWMutex`。

- [ ] **Step 4: 跑测试通过**

```bash
cd instant_share_server && go test ./internal/application/share/... ./internal/domain/share/... ./internal/adapter/share/... -count=1
```

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add instant_share_server/internal/domain/share \
  instant_share_server/internal/application/share \
  instant_share_server/internal/adapter/share
git commit -m "$(cat <<'EOF'
refactor(server): 抽出 share 域与内存用例

EOF
)"
```

---

### Task 3: domain/room + adapter/room/memory + application/room（含 PublicMirror 与回调）

**Files:**
- Create: `instant_share_server/internal/domain/room/{types,errors}.go`
- Create: `instant_share_server/internal/application/room/repository/{room_store,public_mirror}.go`
- Create: `instant_share_server/internal/adapter/room/memory/{room_store,public_mirror}.go`
- Create: `instant_share_server/internal/application/room/service/room_service.go`
- Create: `instant_share_server/internal/application/room/service/room_service_test.go`（迁移 `internal/service/room_test.go`）
- Create: `instant_share_server/internal/application/room/service/mirror_service.go`（Set/Clear/Entries）

**Interfaces:**
- Produces:
  - domain 类型：`SharedFileMeta`、`SharedEntry`、`PendingRequest`、`Member`；错误：`ErrRoomNotActive`、`ErrPairingNotFound`、`ErrPairingExpired`、`ErrInvalidRoomArgument`；`const PairingTTL = 60 * time.Second`
  - ports:
    ```go
    type RoomStore interface { /* 封装现 RoomService 全部状态读写，或直接把现逻辑放 Service + Store 细接口 */ }
    type PublicMirror interface {
        Set(entries []room.SharedEntry)
        Clear()
        Entries() []room.SharedEntry
    }
    type CatalogUpdatedHook func()
    type PendingUpdatedHook func()
    ```
  - `room/service.Service` 方法签名与现 `RoomService` 对齐：
    `EnsureRoom`、`RequestPairing`、`Approve`、`Reject`、`RemoveMember`、`SweepExpired`、`SetOwnerFiles`、`Catalog`、`Members`、`Pending`、`Close`、`IsAuthorizedPeer`、`HostBaseURL`、`HostDeviceID`、`Member`、`RoomID`
  - `func (s *Service) SetHooks(onCatalog, onPending CatalogUpdatedHook / PendingUpdatedHook)`
  - 在 `SetOwnerFiles`/`RemoveMember`/`Approve`/`Close`/`SweepExpired`（导致 pending 变化）等路径末尾调用 hooks（与现 `ws_room` 触发点一致）
  - `MirrorService`：`Set`/`Clear`/`Entries` 委托 `PublicMirror`

- [ ] **Step 1: 迁移 `room_test.go` 到新包并改 import 为 domain/service**

保持用例名与断言语义不变（`TestRoomServiceRequestPairingMergesDevice` 等）。

- [ ] **Step 2: 运行确认失败**

```bash
cd instant_share_server && go test ./internal/application/room/service/ -count=1
```

Expected: FAIL。

- [ ] **Step 3: 从 `internal/service/room.go` + `public_room_catalog.go` 迁实现**

注意：`now func() time.Time` 测试注入保留（导出 `SetNow` 仅测试用，或同包测试可赋值未导出字段——优先同包 `service` 测试）。

- [ ] **Step 4: 测试通过并 commit**

```bash
cd instant_share_server && go test ./internal/application/room/... ./internal/domain/room/... ./internal/adapter/room/... -count=1
git add instant_share_server/internal/domain/room \
  instant_share_server/internal/application/room \
  instant_share_server/internal/adapter/room
git commit -m "$(cat <<'EOF'
refactor(server): 抽出 room 域、镜像端口与回调钩子

EOF
)"
```

---

### Task 4: application/share 公开状态查询用例

**Files:**
- Create: `instant_share_server/internal/application/share/service/public_status.go`
- Create: `instant_share_server/internal/application/share/service/public_status_test.go`（迁移 `handler/share_status_test.go` + `handler/public_test.go` 中纯函数部分）
- Create: `instant_share_server/internal/interfaces/response/public_share.go`（`PublicShareStatus` / `PublicShareFile` / `PublicShareArticle` DTO，json tag 与现 `model` 一致）

**Interfaces:**
- Produces:
  ```go
  // application/share/service
  func BuildPublicShareStatus(
      shareStatus share.Status,
      roomCatalog []room.SharedEntry,
      mirror []room.SharedEntry,
      localBaseURL string,
  ) response.PublicShareStatus
  ```
  规则必须与现 `handler/share_status.go` 的 `buildPublicShareStatus` **逐行等价**（含 mirror 优先注释场景）。
  ```go
  func IsAuthoritativeHost(memberCount int) bool { return memberCount > 0 }
  ```

- [ ] **Step 1: 迁移测试到 `public_status_test.go`，调用 `BuildPublicShareStatus`**

- [ ] **Step 2: 跑测试确认失败 → 实现 → 通过**

```bash
cd instant_share_server && go test ./internal/application/share/service/ -run Public -count=1
```

- [ ] **Step 3: Commit**

```bash
git commit -am "$(cat <<'EOF'
refactor(server): 公开状态组装迁入 share 查询用例

EOF
)"
```

---

### Task 5: delivery + interfaces/system + gateway

**Files:**
- Create: `instant_share_server/internal/delivery/res/json.go`
- Create: `instant_share_server/internal/delivery/router.go`
- Create: `instant_share_server/internal/interfaces/system/controller.go`
- Create: `instant_share_server/internal/interfaces/gateway/controller.go`
- Create: `instant_share_server/internal/application/gateway/service/authenticate.go`

**Interfaces:**
- Produces:
  - `res.WriteJSON` / `WriteError`（行为同现 `handler/api.go` 的 `APIResponse{ok,message,data}`）
  - `system.Controller`：`Health`、`ServerHealth`（字段同现 `model.ServerHealth`，`Share` 用 `share.Status`）
  - `gateway.Controller`：`RegisterUpgrade(mux, ws *websocket.Client)` 挂 `GET/升级 /ws`；`RegisterWS` 设置 `SetAuthFunc` 调 `AuthenticateService`
  - `Authenticate`：允许 `admin`/`peer`/`viewer`（与现 `DefaultAuth` / admin handler 一致；不要收紧）

- [ ] **Step 1: 实现 res + system controller（可先写 ServerHealth 的 httptest）**

- [ ] **Step 2: gateway 注册 WS Client 到 mux（`mux.Handle("/ws", wsClient)`）**

- [ ] **Step 3: `go test` 相关包 + commit**

```bash
git commit -am "$(cat <<'EOF'
refactor(server): 增加 delivery、system 与 gateway 控制器

EOF
)"
```

---

### Task 6: interfaces/share + interfaces/room（拆互持）

**Files:**
- Create: `instant_share_server/internal/interfaces/share/ws_controller.go`
- Create: `instant_share_server/internal/interfaces/room/ws_controller.go`
- Create: `instant_share_server/internal/interfaces/request/*.go`（pairing/share offer 等入参，字段同现 handler 内匿名 struct）
- Create: `instant_share_server/internal/interfaces/share/ws_controller_test.go`（迁移 `handler/ws_admin_test.go`）
- 可选：`interfaces/room` 集成测

**Interfaces:**
- Produces:
  - `share.WSController`：
    - 依赖：`*sharesvc.Service`、`*roomsvc.Service`、`*roomsvc.MirrorService`（或 mirror 端口）、`*websocket.Client`
    - `RegisterWS(client)`：注册 `share.*` 与 `room.public_catalog.*`（用 `shared/consts`）
    - `BroadcastShareStatus()` / `PushShareStatus(conn)`：内部调用 `BuildPublicShareStatus`；权威 Host 时 `mirror=nil`
    - `SyncHostCatalog(status share.Status)`：调用 room `EnsureRoom` + `SetOwnerFiles`（逻辑自 `ws_room.SyncHostCatalog`）
    - `CloseRoom()`：调用 room `Close` + 广播 `room.notify` room_closed（逻辑自 `ws_room.CloseRoom`）
  - `room.WSController`：
    - 依赖：`*roomsvc.Service`、`*websocket.Client`；**不**依赖 `share.WSController`
    - `RegisterWS`：pairing/share.offer/room.*
    - 连接 hook：authorized map（自 `ws_room`）
  - **禁止** `interfaces/room` import `interfaces/share`

- [ ] **Step 1: 先迁 room WS（无 share 依赖）并保证编译**

- [ ] **Step 2: 迁 share WS；`share.start` 成功后调 `SyncHostCatalog`；`share.stop` 先 `CloseRoom` 再广播 status（锁死 `ws_admin_test` 顺序）**

- [ ] **Step 3: 跑迁移后的 `ws_admin_test`**

```bash
cd instant_share_server && go test ./internal/interfaces/share/ -count=1
```

Expected: PASS。

- [ ] **Step 4: Commit**

```bash
git commit -am "$(cat <<'EOF'
refactor(server): 拆分 share/room WS 控制器并解除互持

EOF
)"
```

---

### Task 7: interfaces/public + bootstrap 接线 + 删除旧包

**Files:**
- Create: `instant_share_server/internal/interfaces/public/controller.go`（自 `handler/public.go` + `public_batch.go`）
- Create: `instant_share_server/cmd/deps.go`
- Create: `instant_share_server/cmd/bootstrap.go`
- Modify: `instant_share_server/internal/delivery/router.go` 注册全部控制器
- Modify: `instant_share_server/internal/runtime/runtime.go`：不再 `app.New`；改为 `cmd.Bootstrap(cfg) (handler http.Handler, cleanup func(), deps *AppDeps, err error)` 或等价
- Modify: `instant_share_server/cmd/server/main.go`、`cmd/lib/lib.go`：config import 已指向新包；runtime API 适配
- Delete: `internal/app/`、`internal/handler/`、`internal/service/`、`internal/model/`

**Interfaces:**
- Produces:
  ```go
  // cmd/deps.go
  type AppDeps struct {
      Config config.Config
      Share  *sharesvc.Service
      Room   *roomsvc.Service
      Mirror *roomsvc.MirrorService
      WS     *websocket.Client
  }

  // cmd/bootstrap.go
  func Bootstrap(cfg config.Config) (http.Handler, *AppDeps, func(), error)
  ```
  装配顺序严格按 spec §6。跨域回调：
  ```go
  roomSvc.SetHooks(shareWS.BroadcastShareStatus, shareWS.BroadcastPendingOrCatalog /* pending 用现 broadcastPendingUpdated */)
  ```
  `OnCatalogUpdated` 必须同时：room 内 `room.notify`（仍由 room WS 广播）+ `shareWS.BroadcastShareStatus()`（现 `SetOnCatalogUpdated` 行为）。实现时把「room.notify 广播」留在 `room.WSController` 的 hook 包装里，再调 share 广播——**包装闭包写在 bootstrap**，例如：
  ```go
  roomSvc.SetHooks(func() {
      roomWS.BroadcastCatalogUpdated()
      shareWS.BroadcastShareStatus()
  }, func() {
      roomWS.BroadcastPendingUpdated()
  })
  ```

- [ ] **Step 1: 实现 public controller（status 调 `BuildPublicShareStatus` + `IsAuthoritativeHost`）**

- [ ] **Step 2: 实现 Bootstrap + 改 runtime**

`runtime.Stop` 改为：`deps.Share.Stop()`（若 active）、`deps.WS.Close()`、`Shutdown`。删除对 `app.App` 的引用。

- [ ] **Step 3: 删除旧包，修复所有编译错误**

```bash
cd instant_share_server && go test ./... -count=1
```

Expected: PASS；且不再存在 `internal/handler` 等目录。

- [ ] **Step 4: Commit**

```bash
git add -A instant_share_server
git commit -m "$(cat <<'EOF'
refactor(server): 完成 DDD 装配并删除旧 handler/service/model

EOF
)"
```

---

### Task 8: README + 依赖方向自检

**Files:**
- Modify: `instant_share_server/README.md`（目录结构改为新树；角色/API 说明保持）
- 可选脚本：用 `go list` / 人工 grep 确认 `internal/domain` 无 import `application|adapter|interfaces|delivery|infrastructure`

- [ ] **Step 1: 更新 README 目录树为 spec §4**

- [ ] **Step 2: 依赖自检**

```bash
cd instant_share_server
# domain 不得依赖其它 internal 业务包
rg 'instant_share/server/internal/(application|adapter|interfaces|delivery|infrastructure)' internal/domain && exit 1 || true
# infrastructure 不得依赖 application/interfaces
rg 'instant_share/server/internal/(application|interfaces|delivery|adapter)' internal/infrastructure && exit 1 || true
go test ./... -count=1
```

- [ ] **Step 3: Commit**

```bash
git commit -am "$(cat <<'EOF'
docs(server): 更新 README 目录并完成分层自检

EOF
)"
```

---

### Task 9: 客户端协议核对（默认无改动）

**Files:**
- Verify only: `lib/infrastructure/websocket/ws_constants.dart`
- Verify only: `instant_share_server/web/src/**`（若有硬编码帧类型）

- [ ] **Step 1: 对照 `shared/consts/ws.go` 与 `ws_constants.dart` 字面量**

若完全一致：本任务只记录「无需客户端变更」到 commit message 或跳过 commit。

- [ ] **Step 2: 若有不一致，最小改动 Flutter/Web 并 `flutter analyze` 相关文件**

- [ ] **Step 3: 最终验收**

```bash
cd instant_share_server && go test ./... -count=1
# 若环境允许：
# go build -o /tmp/instant-share ./cmd/server
```

Expected: 全绿；旧包目录不存在。

---

## Self-review（写计划后已核对）

| Spec 项 | 对应 Task |
|---------|-----------|
| 三域 + public 仅 interfaces | Task 2–7 |
| config 上移 / shared / architecture-rules | Task 1、8 |
| 手写 bootstrap、无 Wire | Task 7 |
| 拆 admin↔room 互持 | Task 3 hooks + Task 6–7 |
| 公开状态单一出口 | Task 4 |
| 协议字面量默认不变 | Task 1 consts + Task 9 |
| 删除旧包 | Task 7 |
| 测试迁移 | Task 2–6 |
| README | Task 8 |

无 TBD；类型名在 Task 2–4 定义、Task 6–7 消费处一致。
