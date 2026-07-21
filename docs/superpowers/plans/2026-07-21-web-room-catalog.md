# Web Room Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让浏览器打开 A 或 B 的 `/share` 在房间有效时都能看到聚合目录；下载直连文件所有者本机。

**Architecture:** Host 的 `PublicHandler` / viewer `share.status` 在 `RoomService.Catalog()` 非空时用房间目录覆盖 `files`；Peer 经 Flutter 把同一份 catalog 镜像到本机 Go（admin `room.public_catalog.sync`），再由本机公开 API 输出。本机文件用相对 `download_url`，他机用绝对 URL。

**Tech Stack:** Go（`instant_share_server`）+ Flutter `ShareSessionService` / `MutualShareProvider` + Vite Web（`instant_share_server/web`）

**Spec:** [docs/superpowers/specs/2026-07-21-web-room-catalog-design.md](../specs/2026-07-21-web-room-catalog-design.md)

## Global Constraints

- 下载**直连所有者**，禁止 Host/Peer 代理中转他机文件字节。
- 文章**不**做多机聚合，始终本机 `ShareStatus.articles`。
- 无房间目录（catalog 空且 Peer 镜像空）时，Web 行为与现网一致。
- `active := share.Active || len(publicFiles) > 0`。
- Host 构建公开状态时**以 `RoomService` 为准**，忽略 Peer 镜像 store。
- 批量下载只包含与当前页**同源**的文件（相对 URL 或 origin 匹配）。
- 包名：Flutter `instant_share`；Go `instant_share/server/...`。
- 最小改动；提交前 `go test` / 相关 analyze 通过。

---

## File map（锁定边界）

| 路径 | 职责 |
|------|------|
| `instant_share_server/internal/model/types.go` | `PublicShareFile` 增加可选 `owner_display_name` |
| `instant_share_server/internal/service/public_room_catalog.go` | Peer 侧公开目录镜像 store |
| `instant_share_server/internal/handler/share_status.go` | `buildPublicShareStatus(...)`：合并本机 / 房间 / 镜像 |
| `instant_share_server/internal/handler/share_status_test.go` | 单测覆盖合并规则 |
| `instant_share_server/internal/handler/public.go` | 注入 room + mirror；HTTP status 走 build |
| `instant_share_server/internal/handler/ws_admin.go` | 注册 sync/clear；broadcast/push 走 build；导出广播 |
| `instant_share_server/internal/handler/ws_room.go` | catalog 广播后触发 viewer `share.status` |
| `instant_share_server/internal/app/app.go` | 装配依赖 |
| `lib/infrastructure/websocket/ws_constants.dart` | 新帧类型常量 |
| `lib/infrastructure/websocket/room_ws_models.dart` | `SharedEntryDto.toJson` |
| `lib/infrastructure/websocket/share_ws_admin_client.dart` | sync/clear API |
| `lib/infrastructure/share_server/share_session_service.dart` | 透传 sync/clear |
| `lib/features/mutual_share/provider/mutual_share_provide.dart` | catalog 变更镜像；离房 clear |
| `instant_share_server/web/src/api.ts` | `owner_display_name` |
| `instant_share_server/web/src/main.ts` | 展示所有者；批量下载同源过滤 |
| `instant_share_server/web/src/utils.ts` | `isSameOriginDownloadUrl` 辅助（可选） |
| `docs/mutual-share/requirements.md` 等 | 撤销「Web 不展示 Peer」 |

---

### Task 1: Go — 公开状态合并 `buildPublicShareStatus`

**Files:**
- Modify: `instant_share_server/internal/model/types.go`
- Modify: `instant_share_server/internal/handler/share_status.go`
- Create: `instant_share_server/internal/handler/share_status_test.go`
- Create: `instant_share_server/internal/service/public_room_catalog.go`

**Interfaces:**
- Produces:
  - `PublicShareFile.OwnerDisplayName string \`json:"owner_display_name,omitempty"\``
  - `type PublicRoomCatalog struct` + `NewPublicRoomCatalog()` + `Set([]model.SharedEntry)` + `Clear()` + `Entries() []model.SharedEntry`
  - `func buildPublicShareStatus(share model.ShareStatus, roomCatalog []model.SharedEntry, mirror []model.SharedEntry, localBaseURL string) model.PublicShareStatus`
  - 规则：若 `len(roomCatalog) > 0` 用 room；else 若 `len(mirror) > 0` 用 mirror；else 本机 files。本机条目（`sameBaseURL(entry.BaseURL, localBaseURL)`）→ 相对 download_url；否则绝对。`active = share.Active || len(files) > 0`。articles 始终来自 share。

- [ ] **Step 1: 扩展 `PublicShareFile`**

在 `types.go` 的 `PublicShareFile` 增加：

```go
OwnerDisplayName string `json:"owner_display_name,omitempty"`
```

- [ ] **Step 2: 实现 `PublicRoomCatalog` store**

创建 `instant_share_server/internal/service/public_room_catalog.go`：

```go
package service

import (
	"sync"

	"instant_share/server/internal/model"
)

type PublicRoomCatalog struct {
	mu      sync.RWMutex
	entries []model.SharedEntry
}

func NewPublicRoomCatalog() *PublicRoomCatalog {
	return &PublicRoomCatalog{entries: nil}
}

func (s *PublicRoomCatalog) Set(entries []model.SharedEntry) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if entries == nil {
		s.entries = nil
		return
	}
	cp := make([]model.SharedEntry, len(entries))
	copy(cp, entries)
	s.entries = cp
}

func (s *PublicRoomCatalog) Clear() {
	s.Set(nil)
}

func (s *PublicRoomCatalog) Entries() []model.SharedEntry {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if len(s.entries) == 0 {
		return nil
	}
	cp := make([]model.SharedEntry, len(s.entries))
	copy(cp, s.entries)
	return cp
}
```

- [ ] **Step 3: 写失败单测（合并规则）**

创建 `share_status_test.go`，至少覆盖：

```go
func TestBuildPublicShareStatusLocalOnly(t *testing.T) { ... } // room/mirror 空 → 本机相对 URL
func TestBuildPublicShareStatusPrefersRoomOverMirror(t *testing.T) { ... }
func TestBuildPublicShareStatusMirrorWhenNoRoom(t *testing.T) { ... }
func TestBuildPublicShareStatusRemoteAbsoluteURL(t *testing.T) { ... }
func TestBuildPublicShareStatusActiveWhenFilesFromCatalog(t *testing.T) {
	// share.Active=false, room 有文件 → Active true
}
```

- [ ] **Step 4: 运行单测确认失败**

Run: `cd instant_share_server && go test ./internal/handler/ -run TestBuildPublicShareStatus -v`  
Expected: FAIL（`buildPublicShareStatus` 未定义）

- [ ] **Step 5: 实现 `buildPublicShareStatus`**

在 `share_status.go` 实现合并逻辑；保留 `toPublicShareStatus` 供内部复用或改为调用 `buildPublicShareStatus(status, nil, nil, "")`。

`sameBaseURL`：解析两边 URL，比较 `Scheme+Host`（含 port）；解析失败则字符串 trim 后缀 `/` 后相等。

本机相对路径格式保持：`/api/v1/share/files/%s/download`。  
他机：`url.Parse(baseURL).ResolveReference(downloadPath)` 得到绝对字符串。

- [ ] **Step 6: 再跑单测**

Run: `cd instant_share_server && go test ./internal/handler/ -run TestBuildPublicShareStatus -v`  
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add instant_share_server/internal/model/types.go \
  instant_share_server/internal/service/public_room_catalog.go \
  instant_share_server/internal/handler/share_status.go \
  instant_share_server/internal/handler/share_status_test.go
git commit -m "$(cat <<'EOF'
feat(server): merge room catalog into public share status

EOF
)"
```

---

### Task 2: Go — 接线 PublicHandler / WSAdmin / catalog 触发广播

**Files:**
- Modify: `instant_share_server/internal/handler/public.go`
- Modify: `instant_share_server/internal/handler/ws_admin.go`
- Modify: `instant_share_server/internal/handler/ws_room.go`
- Modify: `instant_share_server/internal/app/app.go`

**Interfaces:**
- Consumes: `buildPublicShareStatus`, `PublicRoomCatalog`, `RoomService.Catalog`
- Produces:
  - `NewPublicHandler(share, room, mirror)`
  - `WSAdminHandler` 持有 `room *service.RoomService` + `mirror *service.PublicRoomCatalog`（可继续持有 `*WSRoomHandler`）
  - `func (h *WSAdminHandler) BroadcastShareStatus()` 导出
  - admin 帧：`room.public_catalog.sync` / `room.public_catalog.clear`
  - `WSRoomHandler.SetOnCatalogUpdated(func())`；在 `broadcastCatalogUpdated` 末尾调用

- [ ] **Step 1: 改造 `NewPublicHandler` 与 `handleShareStatus`**

```go
type PublicHandler struct {
	share  fs.FS
	files  *service.ShareService
	room   *service.RoomService
	mirror *service.PublicRoomCatalog
}

func NewPublicHandler(share *service.ShareService, room *service.RoomService, mirror *service.PublicRoomCatalog) *PublicHandler {
	return &PublicHandler{share: webassets.FS(), files: share, room: room, mirror: mirror}
}
```

`handleShareStatus`：

```go
status := h.files.Status()
catalog, _ := h.room.Catalog()
mirror := h.mirror.Entries()
localBase := h.room.HostBaseURL() // Host 有房间时；Peer 镜像场景 localBase 可用 share 的 HTTP base
data := buildPublicShareStatus(status, catalog, mirror, localBaseFor(h))
```

实现 `localBaseFor`：优先 `room.HostBaseURL()`；若空则用 `ShareService` 已有的对外 base（查 `ShareService` / config；若无现成 getter，用 `fmt.Sprintf("http://%s:%d", host, port)` 与现有 SyncHostCatalog 一致的来源）。**Peer 机器上 `HostBaseURL` 常为空**，此时 `localBase` 应为本机 LAN base，以便镜像里「本机条目」仍出相对 URL。可在 `PublicRoomCatalog` 旁于 sync 时不依赖 HostBaseURL：比较 entry.BaseURL 与请求 `r.Host` 构造的 base，或在 `buildPublicShareStatus` 增加可选 `requestHost`。更简单：**Peer sync 时本机文件的 base_url 已是本机 LAN URL**；`localBase` 取自 health 同款——在 `ShareService` 增加 `HTTPBase() string` 若尚无。先读 `ShareService` / `APIHandler.ServerHealth` 如何拼 `http_base`，复用同一函数。

- [ ] **Step 2: WSAdmin 使用 build + 导出广播**

将 `broadcastShareStatus` / `pushShareStatus` 改为调用 `buildPublicShareStatus`。  
导出：

```go
func (h *WSAdminHandler) BroadcastShareStatus() {
	h.broadcastShareStatus()
}
```

构造函数增加 `room *service.RoomService` 与 `mirror *service.PublicRoomCatalog`（或从现有 `WSRoomHandler` 取 `room` 指针，并另传 mirror）。

- [ ] **Step 3: 注册 `room.public_catalog.sync` / `clear`**

请求体 sync：

```go
type publicCatalogSyncRequest struct {
	Catalog []model.SharedEntry `json:"catalog"`
}
```

admin only；`mirror.Set(req.Catalog)`；`h.broadcastShareStatus()`；ack `room.public_catalog.sync_ack`。  
clear：`mirror.Clear()`；broadcast；ack `room.public_catalog.clear_ack`。

- [ ] **Step 4: catalog_updated 后刷新 viewer**

`WSRoomHandler`：

```go
onCatalogUpdated func()

func (h *WSRoomHandler) SetOnCatalogUpdated(fn func()) { h.onCatalogUpdated = fn }

func (h *WSRoomHandler) broadcastCatalogUpdated() {
	// ... existing broadcast ...
	if h.onCatalogUpdated != nil {
		h.onCatalogUpdated()
	}
}
```

`app.go`：

```go
mirror := service.NewPublicRoomCatalog()
wsRoom := handler.NewWSRoomHandler(room, wsClient)
wsAdmin := handler.NewWSAdminHandler(share, wsClient, wsRoom, room, mirror)
wsRoom.SetOnCatalogUpdated(wsAdmin.BroadcastShareStatus)
public := handler.NewPublicHandler(share, room, mirror)
```

（按实际构造函数签名微调，保证可编译。）

- [ ] **Step 5: 跑 Go 测试**

Run: `cd instant_share_server && go test ./internal/...`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add instant_share_server/internal/handler/public.go \
  instant_share_server/internal/handler/ws_admin.go \
  instant_share_server/internal/handler/ws_room.go \
  instant_share_server/internal/app/app.go
git commit -m "$(cat <<'EOF'
feat(server): expose room catalog on /share status for host and peer mirror

EOF
)"
```

---

### Task 3: Flutter — Peer 镜像 catalog 到本机 Go

**Files:**
- Modify: `lib/infrastructure/websocket/ws_constants.dart`
- Modify: `lib/infrastructure/websocket/room_ws_models.dart`
- Modify: `lib/infrastructure/websocket/share_ws_admin_client.dart`
- Modify: `lib/infrastructure/share_server/share_session_service.dart`
- Modify: `lib/features/mutual_share/provider/mutual_share_provide.dart`

**Interfaces:**
- Produces:
  - `WsFrameType.roomPublicCatalogSync` / `SyncAck` / `Clear` / `ClearAck`
  - `SharedEntryDto.toJson()`
  - `ShareWsAdminClient.syncPublicRoomCatalog(List<SharedEntryDto>)`
  - `ShareWsAdminClient.clearPublicRoomCatalog()`
  - `ShareSessionService` 同名透传
  - `MutualShareProvider`：凡更新 `_catalog` 后（且 `joinedRoom`）调用 sync；`cancelPairing` 先 clear

- [ ] **Step 1: 常量 + `toJson`**

`ws_constants.dart`：

```dart
static const roomPublicCatalogSync = 'room.public_catalog.sync';
static const roomPublicCatalogSyncAck = 'room.public_catalog.sync_ack';
static const roomPublicCatalogClear = 'room.public_catalog.clear';
static const roomPublicCatalogClearAck = 'room.public_catalog.clear_ack';
```

`SharedEntryDto`：

```dart
Map<String, dynamic> toJson() => {
  'id': id,
  'name': name,
  'size': size,
  'owner_id': ownerId,
  if (ownerDisplayName != null) 'owner_display_name': ownerDisplayName,
  'base_url': baseUrl,
  'download_path': downloadPath,
};
```

- [ ] **Step 2: Admin client + SessionService**

```dart
Future<void> syncPublicRoomCatalog(List<SharedEntryDto> catalog) async {
  final response = await _client.request(
    WsFrameType.roomPublicCatalogSync,
    data: {'catalog': catalog.map((e) => e.toJson()).toList()},
  );
  if (!response.isSuccess) {
    throw StateError(response.message ?? 'public catalog sync failed');
  }
}

Future<void> clearPublicRoomCatalog() async {
  final response = await _client.request(WsFrameType.roomPublicCatalogClear);
  if (!response.isSuccess) {
    throw StateError(response.message ?? 'public catalog clear failed');
  }
}
```

`ShareSessionService` 同样透传。

- [ ] **Step 3: MutualShareProvider 接线**

新增：

```dart
Future<void> _mirrorPublicCatalog() async {
  if (_phase != MutualSharePhase.joinedRoom) return;
  try {
    await _session.syncPublicRoomCatalog(_catalog);
  } catch (error) {
    debugPrint('[MutualShareProvider] public catalog sync failed: $error');
  }
}

Future<void> _clearPublicCatalogMirror() async {
  try {
    await _session.clearPublicRoomCatalog();
  } catch (error) {
    debugPrint('[MutualShareProvider] public catalog clear failed: $error');
  }
}
```

调用点：

1. `_handlePairingOutcome` approved：设置 `_catalog` 后 `unawaited(_mirrorPublicCatalog())`（`onJoinedRoom` 前后均可；offer 后还会再来 `catalog_updated`）。
2. `_handleRemoteNotify` / `_handleAdminIncoming` 在 `catalog_updated`（或 catalog 非空更新）后 `unawaited(_mirrorPublicCatalog())`。
3. Host 的 `_handleAdminIncoming` 也会更新 catalog：**Host 不需要镜像**（Go 已读 RoomService）。仅当 `joinedRoom`（Peer）时 mirror——`_mirrorPublicCatalog` 已有 phase 守卫，Host 的 phase 不是 `joinedRoom`，自动跳过。OK。
4. `cancelPairing`：**先** `await _clearPublicCatalogMirror()`，再断开 remote；并把 `_catalog = const []`。

注意：当前 `cancelPairing` 在 idle 时可能提前 return 逻辑——确保离房路径一定会 clear（`leaveRoom` → `cancelPairing`）。若 phase 已是 idle 仍可能残留 mirror，clear 应**无条件**尝试一次（或仅当曾 joined）。推荐：clear 放在 `cancelPairing` 开头，失败只打日志。

- [ ] **Step 4: 静态检查**

Run: `flutter analyze lib/infrastructure/websocket lib/infrastructure/share_server lib/features/mutual_share`  
Expected: 无 error

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/websocket/ws_constants.dart \
  lib/infrastructure/websocket/room_ws_models.dart \
  lib/infrastructure/websocket/share_ws_admin_client.dart \
  lib/infrastructure/share_server/share_session_service.dart \
  lib/features/mutual_share/provider/mutual_share_provide.dart
git commit -m "$(cat <<'EOF'
feat(app): mirror room catalog to local server for peer /share

EOF
)"
```

---

### Task 4: Web — 所有者展示 + 批量下载同源过滤

**Files:**
- Modify: `instant_share_server/web/src/api.ts`
- Modify: `instant_share_server/web/src/utils.ts`
- Modify: `instant_share_server/web/src/main.ts`

**Interfaces:**
- Produces: `ShareFile.owner_display_name?: string`；`isSameOriginDownloadUrl(url: string): boolean`；批量下载只提交同源 id

- [ ] **Step 1: API + utils**

```ts
export interface ShareFile {
  id: string;
  name: string;
  size: number;
  size_text: string;
  download_url: string;
  owner_display_name?: string;
}

export function isSameOriginDownloadUrl(downloadUrl: string): boolean {
  try {
    const resolved = new URL(downloadUrl, window.location.origin);
    return resolved.origin === window.location.origin;
  } catch {
    return false;
  }
}
```

- [ ] **Step 2: 列表 UI 展示所有者**

在文件行名称旁，若 `file.owner_display_name` 存在则显示次要文案（例如 ` · ${owner}`），保持现有布局最小改动。

单文件下载：`href` 使用 `file.download_url`（绝对/相对均可）；QR 继续 `absoluteUrl(file.download_url)`（绝对 URL 时 `URL` 构造仍正确）。

- [ ] **Step 3: 批量下载过滤**

在 batch 按钮处理处：

```ts
const selected = currentFiles.filter((file) => selectedIds.has(file.id));
const localFiles = selected.filter((file) =>
  isSameOriginDownloadUrl(file.download_url),
);
const skipped = selected.length - localFiles.length;
if (localFiles.length === 0) {
  window.alert("所选文件均在其他设备，请逐个下载");
  return;
}
if (skipped > 0) {
  window.alert(`已跳过 ${skipped} 个跨设备文件，请单独下载`);
}
triggerBatchDownload(localFiles.map((f) => f.id));
```

- [ ] **Step 4: 构建 Web 资源**

Run: `cd instant_share_server && make web-build`  
Expected: 成功写入 embed 静态资源

- [ ] **Step 5: Commit**

```bash
git add instant_share_server/web/src/api.ts \
  instant_share_server/web/src/utils.ts \
  instant_share_server/web/src/main.ts \
  instant_share_server/internal/web/  # embed 产物若有变更
git commit -m "$(cat <<'EOF'
feat(web): show room owners and skip cross-origin batch downloads

EOF
)"
```

---

### Task 5: 文档与手工验收

**Files:**
- Modify: `docs/mutual-share/requirements.md`
- Modify: `docs/mutual-share/architecture.md`
- Modify: `docs/mutual-share/plan.md`（验收条目改为「能看到」对方文件）

- [ ] **Step 1: 更新三份文档**

将「PC Web `/share` 不展示 Peer / 聚合目录」改为本设计语义；验收改为：

- 浏览器打开 A 的 `/share` **能看到** B 已 offer 的文件，下载直连 B；
- 浏览器打开 B 的 `/share` **能看到** A 的文件，下载直连 A；
- 离房后对方文件从 Web 消失。

- [ ] **Step 2: 手工验收清单（执行者勾选）**

1. A、B 入房，双方各选至少 1 个文件并完成自动分享/offer。  
2. 浏览器打开 A 的分享链接 → 列表含 A+B 文件；下 B 的文件请求打到 B 的 IP。  
3. 打开 B 的分享链接 → 列表含 A+B；下 A 的文件打到 A 的 IP。  
4. 批量勾选含跨设备文件 → 提示跳过或仅打本地 zip。  
5. B 退出房间 → 刷新 B 的 `/share` 不再出现 A 的文件；A 侧视房间状态更新。

- [ ] **Step 3: Commit**

```bash
git add docs/mutual-share/requirements.md \
  docs/mutual-share/architecture.md \
  docs/mutual-share/plan.md
git commit -m "$(cat <<'EOF'
docs(mutual-share): web /share shows aggregated room catalog

EOF
)"
```

---

## Spec coverage（自检）

| Spec 要求 | Task |
|-----------|------|
| Host `/share` 读 RoomService catalog | 1–2 |
| Peer 镜像 + 离房 clear | 2–3 |
| 本机相对 / 他机绝对 download_url | 1 |
| `active \|\| files` | 1 |
| catalog 变更推 viewer share.status | 2 |
| 文章仍本机 | 1（build 保留 articles） |
| 批量下载同源 | 4 |
| 文档验收反转 | 5 |
| 直连不中转 | 全局约束 + 不改 download handler 代理 |

无 TBD/占位实现步骤。
