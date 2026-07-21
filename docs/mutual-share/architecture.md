# 互相分享（Mutual Share）架构设计

日期：2026-07-20  
状态：已确认（与需求 §10 决策对齐）  
关联需求：[requirements.md](./requirements.md)

## 1. 设计摘要

采用 **单 Host 协调 + 多所有者本机下载** 模型：

- **配对、审批、共享列表聚合、变更通知**：由 Host（A）的 Go 服务 + WS 完成。
- **文件字节**：始终留在文件所有者本机；下载 HTTP 直连所有者服务。
- **角色**：Host 本机 Flutter 仍是唯一 `admin`；对端以 `peer` 加入 Host 的 WS，**禁止**对端以 `admin` 控制 Host。

本期不做下载鉴权（公开下载模型与现网一致）。

## 2. 现状与差距

### 2.1 现状

| 能力 | 现状 |
|------|------|
| 本机 admin WS | `ShareSessionService` + `share.start/stop/sync` |
| 公开下载 | `GET /api/v1/share/status`、`/api/v1/share/files/{id}/download` |
| 角色 | `admin` / `viewer`（`DefaultAuth`） |
| 会话状态 | 单份 `ShareService` / `ShareStatus`（本机文件 + 文章） |

### 2.2 需新增

| 能力 | 说明 |
|------|------|
| 配对协议 | `pairing.request / approve / reject / timeout` |
| 角色 `peer` | 可 offer 元数据、收 notify；不可 admin 控制指令 |
| 房间目录 | Host 侧聚合多所有者文件元数据 |
| Peer 客户端 | Flutter：连远程 Host WS、本机仍保留 admin |
| 共享 UI 态 | Peer 已加入：主题色、顶栏「共享文件」；Host 顶栏不变 |
| 多 Peer | Room 支持多个已批准成员 |
| PC Web | `/share` 展示房间 catalog（Host 读 `RoomService`；Peer 镜像） |

## 3. 总体架构

```text
                    ┌──────────────────────────────────────┐
                    │           Host A                      │
                    │  Flutter (admin @ 127.0.0.1)          │
                    │           │                           │
                    │           ▼                           │
                    │  Go Server A  ◄── WS peer ──┐         │
                    │  - ShareService (A 本机文件) │         │
                    │  - RoomRegistry (成员/目录)  │         │
                    │  - HTTP download (A 文件)   │         │
                    └──────────────┬───────────────┘         │
                                   │ pairing / offer / notify
                                   │
                    ┌──────────────▼───────────────┐
                    │           Peer B              │
                    │  Flutter                      │
                    │  - admin → Server B (本机)    │
                    │  - peer  → Server A (远程 WS) │
                    │  Go Server B                  │
                    │  - ShareService (B 本机文件)  │
                    │  - HTTP download (B 文件)     │
                    └───────────────────────────────┘

下载 A 的文件 → HTTP → Server A
下载 B 的文件 → HTTP → Server B
（不经对方落盘中转）
```

### 3.1 决策表

| 决策 | 选择 | 原因 |
|------|------|------|
| 拓扑 | 单 Host 房间 | 匹配「A 审批、A 发通知」产品流程 |
| 对端角色 | `peer`，非 `admin` | 避免停服/覆盖列表；权限清晰 |
| 大文件 | 所有者本机 URL | 避免 10GB 撑满 Host 磁盘 |
| 下载鉴权 | 本期不做 | 需求明确裁剪 |
| B 是否开服务 | 必须 | 否则无法提供本机下载 |
| 与「双主机互访」关系 | 本期不采用对等双房间 | UI/审批流以 Host 为中心；下载层仍是多 origin |
| 连接入口 | 首页右上角「+」弹窗输 IP | 与底部「添加文件」、中央主按钮加号分离 |
| 成员数 | 多 Peer | 同一 Host 房间可同时有多个已批准成员 |
| Host 顶栏 | 不变 `[分享文章 \| 分享文件]` | 文章尚未多机去重；仅 Peer 切「共享文件」 |
| PC Web `/share` | 房间 catalog 非空时覆盖 `files` | Host 读 `RoomService.Catalog()`；Peer 经 Flutter 镜像到本机 Go；本机相对 / 他机绝对 `download_url`；文章仍本机 |

## 4. 逻辑组件

### 4.1 Go（Host 侧增强为主）

```text
instant_share_server/
└── internal/
    ├── service/
    │   ├── share.go              # 现有：本机分享文件/文章
    │   └── room.go               # 新增：配对、成员、聚合目录
    ├── handler/
    │   ├── ws_admin.go           # 现有 admin 帧
    │   └── ws_room.go            # 新增 peer/pairing/offer/notify 帧
    └── model/
        └── room_types.go         # 新增 DTO
```

| 组件 | 职责 |
|------|------|
| `ShareService` | 不变：仅管理 **本机** 可下载文件路径 |
| `RoomService` | pending 申请、已批准成员、聚合 `SharedEntry[]`、广播 notify |
| WS Gateway | 扩展 `DefaultAuth` 支持 `peer`；按 role 限制可调用的 type |

Peer 本机 Go **仍需要**现有 `ShareService` + 公开下载，以便他人拉取 B 的文件。Peer 本机可不跑完整 `RoomService`（房间状态以 Host 为准）。

### 4.2 Flutter

| 组件 | 职责 |
|------|------|
| `ShareSessionService`（现有） | 本机 admin：启停、同步本机文件/文章 |
| `RemoteRoomClient`（新增） | 连接 Host：`pairing.*`、`share.offer`、收 `notify`、拉目录快照 |
| `MutualShareProvider`（新增） | 组合：本机分享态 + 房间成员/目录 + UI 共享态 |
| 连接 Tab UI | 待审批列表、已连接成员、同意/拒绝 |
| Home UI 态 | `localIdle` / `localSharing` / `joinedRemoteRoom` 等 |

建议状态机（Peer 视角）：

```text
localOnly
  → pairingPending (60s)
  → joinedRoom
  → localOnly   (退出/超时/拒绝/Host 解散)
```

Host 视角在本地分享开启后额外：

```text
sharing
  + pendingRequests[]
  + peers[]
  + roomCatalog[]   // 聚合目录
```

## 5. 角色与权限

| 操作 | admin（本机） | peer（连 Host） | viewer（现有匿名） |
|------|---------------|-----------------|---------------------|
| `share.start/stop/sync`（Host 本机列表） | ✅ 仅本机 | ❌ | ❌ |
| `pairing.request` | ❌ | ✅（申请中） | ❌ |
| `pairing.approve/reject` | ✅（Host Flutter→Host WS 或本地 API） | ❌ | ❌ |
| `share.offer`（元数据） | ✅（Host 发布本机变更时可内部转） | ✅ | ❌ |
| 收 `room.notify` | ✅（App） | ✅ | ❌（Web 经 `share.status` 推送，不订阅 `room.notify`） |
| HTTP 下载所有者文件 | ✅ | ✅（直连所有者） | ✅（本机相对或他机绝对 URL，直连所有者） |

说明：Host Flutter 对**自己**服务始终 `admin`。审批动作由 Host 的 admin 连接发起（或等价本机 HTTP），不开放给 peer。匿名 `viewer` / PC Web 通过 `buildPublicShareStatus` 获取聚合目录（catalog 非空时覆盖 `files`）；无 catalog 时与现网一致（仅本机 `ShareStatus`）。

## 6. 协议设计

消息均走 Host 的 `/ws`，JSON 帧风格与现有 `type` + `request_id` + `data` 对齐。

### 6.1 鉴权首帧

Peer 在配对阶段可先以受限身份连接（实现二选一，工作计划里写死一种）：

**推荐：两段式**

1. 连接后 `auth`：`role=peer`，`device_id=...`，状态 = `pending`（仅允许 pairing 相关帧）。
2. Host `pairing.approve` 后，同连接升级为 `authorized peer`，或要求 B 重连并携带 approve 发放的 `room_token`（**本期不做下载鉴权**；若引入 `room_token` 仅用于 WS 会话识别，不用于 HTTP 下载签名）。

为降低首期复杂度，可采用：

- pending 连接可发 `pairing.request` 并等结果；
- approve 后在同一条连接上标记 `authorized=true`，再允许 `share.offer` 与收 notify。

### 6.2 配对

**B → A：`pairing.request`**

```json
{
  "type": "pairing.request",
  "request_id": "uuid",
  "data": {
    "device_id": "b-device-uuid",
    "display_name": "Bright-Air",
    "peer_base_url": "http://192.168.1.20:8080"
  }
}
```

`peer_base_url`：B 本机服务地址，供目录中 B 文件拼下载 URL，并供 Host 侧展示。

**A → B：`pairing.approve` / `pairing.reject` / `pairing.timeout`**

```json
{
  "type": "pairing.approve",
  "request_id": "uuid",
  "data": {
    "room_id": "session-or-room-id",
    "host_base_url": "http://192.168.1.10:8080"
  }
}
```

超时：Host 侧 pending 超过 60s 删除并通知申请方；申请方本地倒计时归零亦回到可重试态。

### 6.3 发布元数据（非上传文件体）

**→ Host：`share.offer`**

```json
{
  "type": "share.offer",
  "request_id": "uuid",
  "data": {
    "owner_id": "b-device-uuid",
    "base_url": "http://192.168.1.20:8080",
    "files": [
      {
        "id": "file-uuid",
        "name": "movie.mkv",
        "size": 10737418240,
        "download_path": "/api/v1/share/files/file-uuid/download"
      }
    ],
    "revision": 3
  }
}
```

约定：

- `files` 为该所有者的**全量快照**（或明确 `op: set|add|remove`；首期推荐全量快照，实现简单）。
- Host 校验 `owner_id` 与连接身份一致，防止伪造他人 `base_url`。
- Host **不**接收 multipart 文件体作为默认路径。

Host 自身文件变更：可由 admin 在 `share.sync` 成功后内部更新房间目录中 `owner=host` 的条目，再广播。

### 6.4 通知

**Host → 成员：`room.notify`**

```json
{
  "type": "room.notify",
  "data": {
    "event": "catalog_updated",
    "catalog": [
      {
        "id": "file-uuid",
        "name": "movie.mkv",
        "size": 10737418240,
        "owner_id": "b-device-uuid",
        "owner_display_name": "Bright-Air",
        "base_url": "http://192.168.1.20:8080",
        "download_path": "/api/v1/share/files/file-uuid/download"
      }
    ],
    "revision": 4
  }
}
```

客户端下载：`Uri.parse(base_url).resolve(download_path)`（注意相对 path 拼接）。

### 6.5 可选 HTTP（Host）

若审批希望不全部走 admin WS，可增加本机-only HTTP（仍仅 127.0.0.1 或 admin 会话）：

- `GET /api/v1/room/pending`
- `POST /api/v1/room/pending/{id}/approve`
- `POST /api/v1/room/pending/{id}/reject`

与 WS 通知双通道选一为主、另一为辅；工作计划中固定一种主路径。

## 7. 数据模型（Host 内存态）

```text
Room
  room_id
  host_device_id
  host_base_url
  pending: []PendingRequest   // device_id, display_name, peer_base_url, expires_at
  members: []Member           // device_id, display_name, peer_base_url, conn
  catalog: []SharedEntry      // 聚合
  revision: int
```

与现有 `ShareStatus.session_id` 可关联：分享停止时 `Room` 一并销毁并通知成员。

Peer 本机：

- 继续用 `ShareStatus` 管理自己可下载文件。
- `RemoteRoomClient` 只缓存 Host 下发的 `catalog` + 连接态。

## 8. 关键边界

| 边界 | 策略 |
|------|------|
| admin 控制面 | 仅本机 Flutter ↔ 本机 WS；不对局域网开放第二个 admin |
| peer 能力面 | 仅 pairing（pending）+ offer + 收 notify |
| 文件伪造 | `share.offer` 的 `owner_id` / `base_url` 必须与已批准成员登记信息一致 |
| 下载 | 本期不签 token；依赖局域网与现有公开下载（与需求一致） |
| 自己连自己 | 客户端比较 `peer_base_url` / 目标 IP 与本机局域网地址，拒绝 |

> 说明：不做下载鉴权意味着「知道 URL 即可下」。若后续要收紧，再加 token，不作为本期阻塞。

## 9. UI 架构要点

| 界面 | 行为 |
|------|------|
| Home 中央开关 | Host：开/关本机分享（现有）；Host 顶栏始终 `[分享文章 \| 分享文件]` |
| 连接入口 | 首页**右上角「+」**（`HomeSharePageShell.topRight`）→ 弹窗输 IP/端口 → pairing |
| 连接 Tab | Host：pending / 多 members；Peer：可显示已加入的 Host 信息 |
| Peer 顶栏 | `joinedRoom`：`[分享文章 \| 分享文件]` → `[共享文件]`（文章未多机去重） |
| Host 顶栏 | **不切换**，保持文章/文件模式 |
| 背景色 | Peer `joinedRoom` 使用分享色（具体 token 跟 `HomePalette`） |
| App 房间目录 | Host/Peer App 展示 `catalog`；下载走所有者 URL |
| PC Web `/share` | 房间 catalog 非空时展示聚合文件（含 Peer）；本机相对 / 他机绝对下载 URL；文章仍本机；批量下载仅同源 |

入口语义分离：右上角「+」= 连接对方；底部摘要栏加号 / 中央主按钮加号 = 添加本机文件（现有），勿混用。

## 10. 失败与生命周期

```text
Host share.stop
  → Room 销毁
  → 向 peers 发 room.notify(event=room_closed) 或断开 WS
  → Peer UI → localOnly

Peer WS 断开
  → Host 标记 member offline，catalog 中该 owner 条目可保留或标记 stale
  → 下载失败由客户端提示

pairing 超时
  → 清除 pending，通知申请方
```

大文件传输：使用现有 HTTP 下载（流式），App 侧注意勿将整个文件读入内存；与本次房间协议无关，属下载客户端实现约束。

## 11. 测试要点（设计级）

1. 配对：同意 / 拒绝 / 60s 超时；右上角「+」入口可用。
2. 多 Peer：两台及以上 Peer 可同时入房并收到目录更新。
3. 权限：peer 调用 `share.stop` 应 403。
4. 目录：B offer 后 App 内 A/B 目录一致；下载 Host 命中 A、Peer 文件命中 B。
5. 大文件：B offer 10GB 元数据后，A 磁盘占用不因 offer 明显增加。
6. UI：仅 Peer 顶栏切「共享文件」；Host 顶栏仍为文章/文件。
7. PC Web：A/B 双方 `/share` 互见房间文件；下载各打所有者；离房后对方文件消失。
8. Host 停分享：Peer 退出共享 UI；自己连自己被拒绝。

## 12. 里程碑建议（非工作计划）

工作计划建议按下列切片拆任务（详细 tasks 另文）：

1. 协议 + Go `RoomService` + `peer` 角色（多成员）  
2. Flutter `RemoteRoomClient` + 右上角「+」配对弹窗 + 连接 Tab  
3. `share.offer` / `room.notify` + App 房间目录 UI + PC Web 聚合 catalog  
4. Peer 共享态视觉（色 / 顶栏动画；Host 顶栏不动）  
5. 联调与异常路径  

## 13. 明确不采用的方案

| 方案 | 原因 |
|------|------|
| B 以 admin 连 A | 权限过大，双写冲突 |
| B 分块上传文件到 A | 大文件撑满 A 磁盘；与本机路径分享模型不一致 |
| 纯 P2P 无 Host | 与「连接 Tab 审批、Host 通知」产品流不符，首期成本高 |
| Host 代理下载他机文件 | 明确不做；Web 直连所有者 |
| Host 顶栏切「共享文件」 | 文章未多机去重；Host 保持现有双模式 |

---

已与 [requirements.md](./requirements.md) §10 对齐。  
工作计划：[plan.md](./plan.md)
