# Web `/share` 展示房间聚合目录

日期：2026-07-21  
状态：已确认  
关联：`docs/mutual-share/*`（本变更撤销「Web 不展示 Peer 文件」决策）

## 背景

互相分享房间的聚合目录目前只存在于 Host 的 `RoomService` + Flutter App（`MutualShareProvider.catalog`）。PC Web `/share` 仅读取本机 `ShareService` / `GET /api/v1/share/status`，因此：

- 打开 A（Host）的分享链接看不到 B 的文件；
- 打开 B（Peer）的分享链接看不到 A 的文件。

产品现要求：**浏览器打开任意一方的 `/share`，在房间有效时都能看到双方（及所有 Peer）发布的文件**；下载直连文件所有者本机（与 App 一致，不经第三方中转）。

## 目标

1. 房间存在非空聚合 catalog 时，A / B 的 `/share` 文件列表均展示该 catalog。
2. 下载 URL：本机文件可用相对路径；他机文件必须为绝对地址 `base_url + download_path`，浏览器直连所有者。
3. 目录变更时，已打开的 Web 页经现有 viewer `share.status` 推送近实时刷新。
4. 未入房或 catalog 为空时，Web 行为与现网一致（仅本机 `ShareStatus`）。

## 非目标

| 项 | 说明 |
|----|------|
| Host 代理 / 中转下载他机文件 | 明确不做；直连所有者 |
| 多机文章聚合 | 文章仍只展示**当前打开这台机器**的本机文章 |
| 下载鉴权 / 短期 token | 保持现网公开下载 |
| 改配对 / 审批流程 | 不变 |
| 公网 / NAT 穿透 | 仍仅保证同一局域网 |

## 决策摘要

| 决策 | 选择 |
|------|------|
| 下载 | 直连所有者（方案 A） |
| 架构 | Host 读 `RoomService`；Peer 由 Flutter 镜像 catalog 到本机 Go |
| 列表来源优先级 | 公开房间目录非空 → 用房间目录映射为 `files`；否则 → 本机 `ShareStatus.files` |
| 批量下载 | 仅打包与当前页面**同源**的文件；跨设备文件单独下载 |
| 文章 | 始终本机，不合并房间 |

## 架构

```text
                    ┌─────────────────────────────────────┐
                    │ Host Go                             │
  App offer/sync ──►│ RoomService.catalog                 │
                    │        │                            │
                    │        ▼                            │
                    │ PublicHandler / share.status        │
                    │   files ← catalog（绝对 download_url）│
                    └─────────────────────────────────────┘
                                      │
                    room.notify catalog_updated
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │ Peer Flutter                        │
                    │   MutualShareProvider.catalog       │
                    │        │                            │
                    │        ▼ admin WS                   │
                    │ Peer Go: PublicRoomCatalog store    │
                    │        │                            │
                    │        ▼                            │
                    │ PublicHandler / share.status        │
                    │   files ← mirrored catalog          │
                    └─────────────────────────────────────┘

Web viewer ──GET/WS──► 当前打开机器的 /api/v1/share/status
下载他机文件 ──直连──► owner.base_url + download_path
```

## 组件设计

### 1. 公开状态模型（Go）

`PublicShareFile` 增加可选字段：

- `owner_display_name`（`omitempty`）：Web 可展示「谁分享的」；缺省不破坏旧客户端。

`download_url`：

- 本机条目：相对路径 `/api/v1/share/files/{id}/download`（与现网一致）；
- 他机条目：绝对 URL（由 `base_url` resolve `download_path`）。

判断「本机」：条目 `base_url` 与当前服务对外 base（或请求 Host）同源时用相对路径；否则绝对 URL。为简化实现，**房间 catalog 映射时一律输出绝对 `download_url`**（对本机也可用绝对 LAN URL），Web 已支持 `absoluteUrl` 工具；或对本机仍输出相对路径以利批量下载同源检测——**推荐：本机相对、他机绝对**，便于批量下载过滤。

### 2. Host：`PublicHandler` + `share.status` 广播

- `NewPublicHandler(share, room)` 注入 `RoomService`。
- 新增 `buildPublicShareStatus()`：
  1. `base := toPublicShareStatus(share.Status())`（保留 `active` / `session_id` / `articles`）；
  2. 若 `room.Catalog()` 长度 > 0，则用 catalog 覆盖 `base.Files`；
  3. 否则保持本机 files。
- `handleShareStatus` 与 `WSAdminHandler.broadcastShareStatus` / `pushShareStatus` 均走 `buildPublicShareStatus()`，避免 HTTP 与 WS 不一致。
- `WSRoomHandler.broadcastCatalogUpdated` 成功后，触发一次 `broadcastShareStatus()`（或等价回调），让 viewer 网页刷新文件列表。

本机文件下载 API **不代理**他机文件；他机下载不经过 Host 的 `/api/v1/share/files/...`。

### 3. Peer：公开目录镜像

Peer 本机没有 Host 的 `RoomService` 权威数据，由 Flutter 写入缓存：

- 新 admin WS 方法，例如 `room.public_catalog.sync`：
  - 请求体：`{ "catalog": [ SharedEntry... ] }`（可与现有 `SharedEntry` JSON 对齐）；
  - 服务端存入 `PublicRoomCatalog`（或挂在 `ShareService` / 独立小 store）；
  - 写入后 `broadcastShareStatus()`。
- `room.public_catalog.clear`（或 sync 空列表）：离房 / 取消配对时清空。
- Peer 的 `buildPublicShareStatus()`：若镜像 catalog 非空则覆盖 `files`；否则本机列表。

Flutter：

- `MutualShareProvider` 在更新 `_catalog` 后（入房快照、`catalog_updated`、offer ack 等）调用 `ShareSessionService.syncPublicRoomCatalog(catalog)`；
- `leaveRoom` / `cancelPairing` 时 `clearPublicRoomCatalog()`；
- Host 侧可不写镜像（Host 直接读 `RoomService`）；若 Host 误调 sync，可 no-op 或同样写入（以 `RoomService` 优先为准，避免双源冲突——**Host 以 RoomService 为准，忽略镜像**）。

### 4. Web 前端

- `ShareFile` 增加可选 `owner_display_name`；列表 UI 有则展示。
- 下载继续使用 `download_url`（支持绝对地址）；单文件 `<a href>` / 导航下载即可，无需 CORS preflight。
- 批量下载：只收录 `download_url` 为相对路径或与 `location.origin` 同源的文件；若选中含跨设备文件，提示「跨设备文件请单独下载」或自动跳过他机文件并说明。
- 仍订阅 viewer `share.status`；无需订阅 `room.notify`。

### 5. 文档

更新 `docs/mutual-share/requirements.md`、`architecture.md`、`plan.md` 中「PC Web 不展示 Peer / 聚合目录」相关条目，改为本设计语义，并调整验收标准：

- 浏览器打开 A 的 `/share` **能看到** B 已 offer 的文件，且下载直连 B；
- 浏览器打开 B 的 `/share` **能看到** A 的文件，且下载直连 A。

## 错误与边界

| 场景 | 行为 |
|------|------|
| 房间关闭 / Peer 离房 | Host catalog 清空或无 Peer 条目；Peer 清空镜像 → Web 回到本机列表 |
| 他机离线 / 下载失败 | 浏览器直连失败；不在 Host 上重试代理 |
| 仅 Host 有文件、尚无 Peer offer | catalog 可仅含 host 条目；Web 显示这些文件 |
| 本机未 `share.active` 但公开房间目录非空 | `files` 仍按优先级用房间目录；`active := share.Active \|\| len(publicFiles) > 0`，避免页面有文件却显示「等待分享」。 |
| 文件 ID 跨设备可能碰撞 | 下载走绝对 URL + 所有者服务，不在单机 `FileByID` 混查；列表展示以 catalog 条目为准 |

## 测试要点

1. Go：`buildPublicShareStatus` — 无 catalog 时与现网一致；有 catalog 时 files 覆盖且他机 URL 为绝对地址。
2. Go：catalog 更新后 viewer 收到的 `share.status` files 与 HTTP GET 一致。
3. Go：Peer `public_catalog.sync` / clear 影响 status。
4. 手工：A/B 互选文件后，分别打开双方 `/share`，互见且下载落到正确机器。
5. 手工：离房后 Web 不再显示对方文件。
6. 批量下载不含跨 origin 文件。

## 实现顺序（摘要）

1. Go 模型 + `buildPublicShareStatus`（Host 接 RoomService）+ catalog 变更触发 broadcast。
2. Go Peer 公开目录 store + admin WS sync/clear。
3. Flutter `ShareSessionService` + `MutualShareProvider` 接线。
4. Web 展示 owner、批量下载同源过滤。
5. 更新 mutual-share 文档与验收。

## 风险

- Peer 镜像延迟：以 `catalog_updated` 驱动 sync，短暂不一致可接受。
- 绝对 URL 依赖 Peer/Host 上报的 `base_url` 在浏览者局域网可达（与 App 相同前提）。
- 旧嵌入式 server 二进制需随 App 一起更新，否则仅新逻辑不生效。
