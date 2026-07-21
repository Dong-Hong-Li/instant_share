# Instant Share Server

极速分享 Go 后端。身份分为 **admin（发起者）** 与 **接收者（只读访客）**。

## 角色

| 角色 | 通道 | 能力（当前阶段） |
|------|------|------------------|
| **admin** | WebSocket `/ws` | 开启分享 `share.start`、关闭分享 `share.stop` |
| **接收者** | HTTP `/share` | 只读查看当前分享的文件列表，暂无其它操作 |

## 目录结构

分层约定见 [`docs/architecture-rules.md`](docs/architecture-rules.md)。

```text
instant_share_server/
├── cmd/                 # server / lib 入口 + bootstrap 装配
├── config/
├── shared/{consts,errmsg}/
├── docs/architecture-rules.md
├── internal/
│   ├── delivery/        # 路由组装、统一 JSON 响应
│   ├── interfaces/      # system / gateway / share / room / public 控制器
│   ├── application/     # gateway / share / room 用例 + ports
│   ├── domain/          # share / room 领域模型
│   ├── adapter/         # memory 实现
│   ├── infrastructure/websocket/
│   ├── runtime/
│   ├── util/
│   └── web/             # embed 静态资源
├── web/                 # 前端源码
├── go.mod
└── Makefile
```

## 运行

```bash
cd instant_share_server
go run ./cmd/server
```

默认监听 `0.0.0.0:8080`：

- 接收者浏览：`http://<局域网IP>:8080/share`
- admin 控制：`ws://127.0.0.1:8080/ws`

## admin WebSocket

### 鉴权（首帧）

```json
{
  "type": "auth",
  "role": "admin",
  "device_id": "desktop"
}
```

响应：`auth_ack`

### 分享控制

| type | 说明 |
|------|------|
| `share.start` | 开启分享，`data.files` 为文件列表（含绝对路径） |
| `share.stop` | 关闭分享 |

`share.start` 示例：

```json
{
  "type": "share.start",
  "request_id": "1",
  "data": {
    "files": [
      { "id": "optional-uuid", "path": "/absolute/path/file.pdf", "name": "file.pdf" }
    ]
  }
}
```

响应：`share.start_ack`，`data.base_url` 为 `http://<ip>:<port>/share`

## HTTP（admin 探测 + 接收者）

| 路径 | 说明 |
|------|------|
| `GET /api/v1/server/health` | admin 启动前探测，返回 `ws_url` / `share_url` |
| `/health` | 简单健康检查 |
| `/share` | 接收者只读文件列表页 |
| `/ws` | admin WebSocket 升级入口 |

### admin 健康探测

`GET /api/v1/server/health`

```json
{
  "ok": true,
  "data": {
    "service": "instant-share-server",
    "healthy": true,
    "port": 8080,
    "lan_ip": "192.168.1.100",
    "http_base": "http://127.0.0.1:8080",
    "ws_url": "ws://127.0.0.1:8080/ws",
    "share_url": "http://192.168.1.100:8080/share"
  }
}
```

Flutter admin 应先请求该接口获取 `ws_url`，失败则根据 `message` 提示用户；**不要**写死 WebSocket 地址。

## Flutter 集成

桌面端先 `GET http://127.0.0.1:8080/api/v1/server/health`，再连返回的 `ws_url` 作为 **admin** 执行 `share.start` / `share.stop`；接收者浏览器打开 `share_url` 查看文件列表。
