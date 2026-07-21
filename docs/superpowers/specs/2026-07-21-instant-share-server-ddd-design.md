# Instant Share Server DDD 重构设计

日期：2026-07-21  
状态：待实现  
参考：`/Users/bright/Desktop/project/golang/bright-im/bright-im`（分层与依赖方向）

## 1. 背景与问题

`instant_share_server` 约 4k 行，当前扁平结构为 `handler` / `service` / `model`。随互享房间、公开目录镜像等能力叠加，出现：

- `WSAdminHandler` 与 `WSRoomHandler` 互相持有，跨切面耦合
- 公开状态组装（本机 share + room catalog + public mirror）散落在 handler
- `service` / `model` 按技术层堆叠，而非按业务域划分，后续扩展成本高

目标：一次性对齐 bright-im 的 DDD + Ports & Adapters 目录与依赖规则，清理结构；协议允许小幅整理并同步客户端。

## 2. 已确认决策

| 项 | 决策 |
|---|---|
| 对齐程度 | 完整分层：domain / application / adapter / delivery / interfaces / infrastructure |
| 对外契约 | 路径与主流程兼容；允许统一错误码、常量归一，可同步改 Flutter/Web |
| 依赖注入 | 手写 `bootstrap` + `AppDeps`，不引入 Wire |
| 迁移节奏 | 一次到位：新骨架落地后删除旧 `handler` / `service` / `model` / `app` / `internal/config` |
| 限界上下文 | 三域：`gateway` / `share` / `room`；公开页仅在 `interfaces/public` 编排 |
| HTTP 路由 | 继续标准库 `ServeMux`，不强制引入 chi |

## 3. 限界上下文

```text
                    ┌─────────────┐
                    │   gateway   │  WS 鉴权 / 角色 / 连接生命周期
                    └──────┬──────┘
                           │ 转发业务帧
           ┌───────────────┼───────────────┐
           ▼                               ▼
    ┌─────────────┐                 ┌─────────────┐
    │    share    │                 │    room     │
    │ 本机分享会话 │                 │ 互享配对房间 │
    └──────┬──────┘                 └──────┬──────┘
           │                               │
           └───────────┬───────────────────┘
                       ▼
              interfaces/public
           （编排公开状态 / 下载 / 静态页）
```

| 域 | 负责 | 不负责 |
|---|---|---|
| **gateway** | WS 升级、`auth`、admin/viewer 角色、connect/disconnect hook、按 role 广播的基础设施钩子 | share/room 业务规则 |
| **share** | 本机分享启停、文件/文章同步、本机 `ShareStatus`、按 id 查本地文件；公开状态**查询用例**（只读组合入参） | 配对、成员、远端目录镜像 |
| **room** | EnsureRoom、配对申请/审批/拒绝、成员、owner catalog 聚合、pending 过期、**远端公开目录镜像**（原 `PublicRoomCatalog`） | 本机分享启停、HTTP 静态资源 |
| **public（仅 interfaces）** | 组合 share+room 产出公开状态；文件下载/打包；embed Web | 自有 domain/application |

### 跨域通知

- 禁止 Controller 互相 import。
- `room` 用例在 catalog/pending 变更后调用注入的 `OnCatalogUpdated` / `OnPendingUpdated` 回调（在 `application/room` 以函数类型或小接口声明）。
- **bootstrap 装配时**把回调接到 `interfaces/share` 的广播方法（向 viewer 推送公开/分享状态）；不在 `interfaces/room` 内直接依赖 share 控制器。
- 原 `handler/share_status.go` 的组装逻辑进入 `application/share` 只读查询用例；`interfaces/public` 只做 HTTP 翻译。

## 4. 目标目录

```text
instant_share_server/
├── cmd/
│   ├── server/                 # main + parent_unix/windows（保留）
│   ├── lib/                    # CGO/动态库入口（保留）
│   ├── bootstrap.go            # 启 infra → 手写装配
│   └── deps.go                 # AppDeps、注册列表
├── config/                     # 从 internal/config 上移
├── docs/
│   └── architecture-rules.md   # 精简自 bright-im，适配本服务
├── shared/
│   ├── consts/                 # 包类型、角色等常量
│   └── errmsg/                 # 统一错误文案 / 业务码
├── internal/
│   ├── delivery/               # router、middleware、binding、res
│   ├── interfaces/
│   │   ├── gateway/
│   │   ├── system/                 # health 探测
│   │   ├── share/
│   │   ├── room/
│   │   ├── public/
│   │   ├── request/
│   │   └── response/
│   ├── application/
│   │   ├── gateway/{repository,service}/
│   │   ├── share/{repository,service}/
│   │   └── room/{repository,service}/
│   ├── domain/{gateway,share,room}/
│   ├── adapter/
│   │   ├── share/memory/
│   │   ├── room/memory/        # RoomStore + PublicMirror
│   │   └── gateway/            # 按需：WS 查询/投递适配
│   ├── infrastructure/websocket/
│   ├── runtime/                # 保留
│   ├── util/                   # netutil、mime（无业务）
│   └── web/                    # embed（保留）
├── web/                        # 前端源码（保留）
├── go.mod
└── Makefile
```

### 依赖方向（必须遵守）

```text
interfaces  →  application  →  domain
adapter     →  application（实现端口）+ infrastructure + domain
infrastructure → 仅标准库 / 第三方；不依赖 application / interfaces / delivery
domain      →  无 inward 依赖
```

与 bright-im 一致：`infrastructure/websocket.Client` 作为无业务语义基础能力时，application/interfaces 可直接注入使用，无需再包一层 Repository；带领域语义的存储必须经 adapter。

### 删除的旧包

重构完成后删除：`internal/app/`、`internal/handler/`、`internal/service/`、`internal/model/`、`internal/config/`。

## 5. 旧文件落点

| 旧文件 | 新落点 |
|---|---|
| `service/share.go` | `domain/share` + `application/share/service` + `adapter/share/memory` |
| `service/room.go` | `domain/room` + `application/room/service` + `adapter/room/memory` |
| `service/public_room_catalog.go` | `application/room` 镜像端口 + `adapter/room/memory` |
| `model/*.go` | 实体/值对象 → 各 `domain/*`；HTTP/WS DTO → `interfaces/request\|response` |
| `handler/ws_admin.go` | `interfaces/share`（WS） |
| `handler/ws_room.go` | `interfaces/room`（WS） |
| `handler/api.go` | `interfaces/system`（`/health`、`/api/v1/server/health`）；分享启停若仍有 HTTP 则归 `interfaces/share` |
| `handler/public*.go` + `share_status.go` | `interfaces/public` + `application/share` 查询用例 |
| `handler/*_test.go` / `service/*_test.go` | 随用例/控制器迁到对应包 |
| `app/app.go` | `cmd/bootstrap.go` + `delivery/router.go` |
| `internal/config/*` | 根目录 `config/` |

## 6. 装配顺序

```text
1. config.Load
2. 启动 infrastructure/websocket.Client
3. 创建 memory adapter（share store / room store / public mirror）
4. 创建 application services（注入 ports + 跨域回调）
5. 创建 interfaces controllers
6. delivery.RegistrationRoutes → http.Handler
7. runtime 监听（cmd/server 与 cmd/lib 共用 bootstrap）
```

`cmd/server` 与 `cmd/lib` 只负责进程/库生命周期，业务装配集中在 `bootstrap` / `deps`。

## 7. 协议整理范围

**保持不变：**

- HTTP：`/health`、`/api/v1/server/health`、`/share`、`/ws`
- 主流程：admin auth → share.start/stop/sync；room pairing；公开只读浏览与下载

**允许本轮整理：**

- `shared/errmsg`：统一 WS/HTTP 错误码字段与文案出口
- `shared/consts`：包类型/角色常量集中，与现网命名对齐，仅去重与归一
- 公开状态单一查询出口（字段语义以兼容为主）

**本轮不做：**

- 重做鉴权（不加 JWT）
- 大改 URL 路径
- 新增业务能力

若调整帧字段名：实现计划中列对照表，同变更同步 `lib/infrastructure/websocket/*`（及必要的 Web 前端）。

## 8. 测试与验收

| 层级 | 内容 |
|---|---|
| 域/用例 | `domain/*`、`application/*/service` 单测（含现有 `room_test`） |
| 公开状态 | `application/share` 查询用例单测（现有 `share_status_test`） |
| WS 集成 | 保留 dial 风格测试，挂在 `interfaces` 或顶层 `test/` |
| 构建 | `go test ./...`；Makefile / `cmd/server` / `cmd/lib` / web embed 路径不破 |

**成功标准：**

1. 旧四包（及 `internal/config`）删除，依赖方向符合 `docs/architecture-rules.md`
2. 行为基本等价；协议 diff 有清单且客户端已同步（若有字段变更）
3. server、lib、web embed 均可构建

## 9. 非目标

- 引入 Wire、chi、Redis、持久化
- 微服务拆分或多进程
- Flutter UI 重构（仅协议同步所需的最小客户端改动）

## 10. 实现顺序建议

1. 落地 `docs/architecture-rules.md` 与空目录骨架 + `shared` / `config` 迁移
2. 迁 `domain` + memory `adapter` + `application`（share → room → gateway）
3. 迁 `interfaces` + `delivery`，接上跨域回调
4. 改 `cmd/bootstrap`，删除旧包
5. 跑通测试与构建；按协议清单同步客户端（如需要）
6. 更新 `instant_share_server/README.md` 目录说明
