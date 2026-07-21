package gateway

import (
	"net/http"

	infraws "instant_share/server/internal/infrastructure/websocket"
)

// Controller WebSocket 网关 HTTP 控制器。
type Controller struct {
	ws *infraws.Client
}

// NewController 创建网关控制器。
func NewController(ws *infraws.Client) *Controller {
	return &Controller{ws: ws}
}

// SetAuthFunc 设置 WebSocket 鉴权回调。
func (c *Controller) SetAuthFunc(fn infraws.AuthFunc) {
	c.ws.SetAuthFunc(fn)
}

// Register 注册 /ws 路由。
func (c *Controller) Register(mux *http.ServeMux) {
	mux.Handle("/ws", c.ws)
}
