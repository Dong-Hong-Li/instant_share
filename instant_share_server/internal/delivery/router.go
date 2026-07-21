package delivery

import (
	"net/http"

	"instant_share/server/internal/interfaces/gateway"
	"instant_share/server/internal/interfaces/public"
	"instant_share/server/internal/interfaces/system"
)

// RegistrationRoutes 组装 HTTP 路由。
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
