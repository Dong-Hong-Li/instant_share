// Package gateway WebSocket 网关 HTTP 入口：/ws 升级与鉴权委托。
package gateway

import (
	"net/http"

	infraws "instant_share/server/internal/infrastructure/websocket"
)

// Controller WebSocket 网关 HTTP 控制器。
type Controller struct {
	ws *infraws.Client // 基础设施 WS 服务（含连接池与帧路由）
}

// NewController 创建网关控制器。
func NewController(ws *infraws.Client) *Controller {
	return &Controller{ws: ws}
}

// SetAuthFunc 设置 WebSocket 握手鉴权回调（bootstrap 注入 gateway Authenticate）。
func (c *Controller) SetAuthFunc(fn infraws.AuthFunc) {
	c.ws.SetAuthFunc(fn)
}

// Register 注册 /ws 路由，由 http.Server 直接 Serve HTTP 升级。
func (c *Controller) Register(mux *http.ServeMux) {
	mux.Handle("/ws", c.ws)
}
