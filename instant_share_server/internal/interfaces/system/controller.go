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
	share  *sharesvc.Service
	config config.Config
}

// NewController 创建系统控制器。
func NewController(share *sharesvc.Service, cfg config.Config) *Controller {
	return &Controller{share: share, config: cfg}
}

// Register 注册路由。
func (c *Controller) Register(mux *http.ServeMux) {
	mux.HandleFunc("/health", c.Health)
	mux.HandleFunc("/api/v1/server/health", c.ServerHealth)
}

// Health 返回服务健康状态。
func (c *Controller) Health(w http.ResponseWriter, _ *http.Request) {
	res.WriteJSON(w, http.StatusOK, res.APIResponse{
		OK:   true,
		Data: map[string]string{"service": "instant-share-server"},
	})
}

// ServerHealth admin 探测：返回 WebSocket 地址与服务可用状态。
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
