# instant_share_server 架构规则

对齐 bright-im 的 DDD + Ports & Adapters；本服务体量更小，无 Redis / Raft / Wire。

## 1. 分层

```text
cmd/                    启动、手写 bootstrap、AppDeps
  ↓
delivery/               HTTP 路由组装、统一响应
  ↓
interfaces/             控制器：HTTP/WS 入参出参与 application 翻译
  ↓
application/            用例编排 + 端口（repository）
  ↓
domain/                 实体、值对象、领域规则（无 I/O）
  ↑
adapter/                实现 application 端口（多为 memory）
  ↓
infrastructure/         无业务语义基础能力（WebSocket Client 等）
```

## 2. 依赖方向

```text
interfaces  →  application  →  domain
adapter     →  application（实现端口）+ infrastructure + domain
infrastructure → 仅标准库 / 第三方
domain      →  无 inward 依赖
```

**禁止：**

- domain import application / infrastructure / adapter / interfaces / delivery
- infrastructure 依赖 application / interfaces / delivery / adapter
- interfaces / delivery 写业务规则
- application 直接操作 HTTP ResponseWriter / WebSocket 连接帧拼装（协议翻译在 interfaces）
- Controller 互相 import（跨域通知用 bootstrap 回调）

**例外：** `infrastructure/websocket.Client` 无业务语义时，application/interfaces 可直接注入。

## 3. 限界上下文

| 域 | 职责 |
|---|---|
| gateway | WS 升级、auth、角色、连接生命周期钩子 |
| share | 本机分享会话；公开状态只读查询用例 |
| room | 互享配对、成员、catalog、公开目录镜像 |
| public（仅 interfaces） | /share 静态页、status、下载；编排 share+room |

## 4. 包路径约定

- 配置：`instant_share/server/config`
- 常量/错误文案：`instant_share/server/shared/{consts,errmsg}`
- 业务代码：`instant_share/server/internal/...`
