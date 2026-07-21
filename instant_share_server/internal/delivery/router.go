// Package delivery HTTP 路由装配与通用响应工具。
package delivery

import (
	"net/http"

	"instant_share/server/internal/interfaces/gateway"
	"instant_share/server/internal/interfaces/public"
	"instant_share/server/internal/interfaces/system"
)

/**
 * @description: RegistrationRoutes 组装整站 HTTP 路由（system → gateway → public）。
 * WebSocket 帧路由在 bootstrap 单独注册，不在此 mux。
 * @param {*system.Controller} systemCtrl 健康探测
 * @param {*gateway.Controller} gatewayCtrl /ws
 * @param {*public.Controller} publicCtrl 分享页与下载
 * @return {*http.ServeMux}
 */
func RegistrationRoutes(
	systemCtrl *system.Controller,
	gatewayCtrl *gateway.Controller,
	publicCtrl *public.Controller,
) *http.ServeMux {
	mux := http.NewServeMux()
	systemCtrl.Register(mux)
	gatewayCtrl.Register(mux)
	publicCtrl.Register(mux)
	return mux
}
