// Package system 系统探测 HTTP 入口：健康检查与 Admin 启动前 server/health。
package system

import (
	"fmt"
	"net/http"

	"instant_share/server/config"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/internal/delivery/res"
	"instant_share/server/internal/interfaces/request"
	"instant_share/server/internal/util"
)

// Controller 系统健康探测 HTTP 控制器。
type Controller struct {
	share  *sharesvc.Service // 附带当前分享快照
	config config.Config     // 监听端口等
}

// NewController 创建系统控制器。
func NewController(share *sharesvc.Service, cfg config.Config) *Controller {
	return &Controller{share: share, config: cfg}
}

// Register 注册 /health 与 /api/v1/server/health。
func (c *Controller) Register(mux *http.ServeMux) {
	mux.HandleFunc("/health", c.Health)
	mux.HandleFunc("/api/v1/server/health", c.ServerHealth)
}

// Health 轻量存活探测，无业务依赖。
func (c *Controller) Health(w http.ResponseWriter, _ *http.Request) {
	res.WriteJSON(w, http.StatusOK, res.APIResponse{
		OK:   true,
		Data: map[string]string{"service": "instant-share-server"},
	})
}

/**
 * @description: ServerHealth Admin 客户端启动前探测：LAN IP、WS/HTTP 地址与分享状态。
 * @param {*http.Request} r 仅支持 GET
 */
func (c *Controller) ServerHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		res.MethodNotAllowed(w)
		return
	}

	port := c.config.Port
	localIPs := util.LocalIPs()
	lanIP := localIPs[0]

	res.WriteJSON(w, http.StatusOK, res.APIResponse{
		OK: true,
		Data: request.ServerHealth{
			Service:  "instant-share-server",
			Healthy:  true,
			Port:     port,
			LANIP:    lanIP,
			LocalIPs: localIPs,
			HTTPBase: fmt.Sprintf("http://127.0.0.1:%d", port),
			WSURL:    fmt.Sprintf("ws://127.0.0.1:%d/ws", port),
			ShareURL: fmt.Sprintf("http://%s:%d/share", lanIP, port),
			Share:    c.share.Status(),
		},
	})
}
