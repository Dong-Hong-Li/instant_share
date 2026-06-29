package app

import (
	"net/http"

	"instant_share/server/internal/config"
	"instant_share/server/internal/handler"
	infraws "instant_share/server/internal/infrastructure/websocket"
	"instant_share/server/internal/service"
)

// App 聚合 HTTP 与 WebSocket 路由。
type App struct {
	Config config.Config
	Share  *service.ShareService
	WS     *infraws.Client
	Mux    *http.ServeMux
}

// New 创建应用实例。
func New(cfg config.Config) *App {
	share := service.NewShareService(cfg.Host, cfg.Port)
	wsClient := infraws.NewClient(cfg.WebSocket)
	wsAdmin := handler.NewWSAdminHandler(share, wsClient)
	wsAdmin.Register(wsClient)

	mux := http.NewServeMux()

	api := handler.NewAPIHandler(share, cfg)
	mux.HandleFunc("/health", api.Health)
	mux.HandleFunc("/api/v1/server/health", api.ServerHealth)

	// 发起者 admin：WebSocket 控制分享启停
	mux.Handle("/ws", wsClient)

	// 接收者：打包后的 Web 前端（/share/）+ 公开状态 API
	public := handler.NewPublicHandler(share)
	public.Register(mux)

	return &App{
		Config: cfg,
		Share:  share,
		WS:     wsClient,
		Mux:    mux,
	}
}

// Addr 返回 HTTP 监听地址。
func (a *App) Addr() string {
	return a.Config.Addr()
}
