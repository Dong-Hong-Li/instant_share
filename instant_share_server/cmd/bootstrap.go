// Package cmd 提供服务装配与依赖容器（cmd/server、cmd/lib 与 runtime 共用）。
package cmd

import (
	sharememory "instant_share/server/internal/adapter/share/memory"
	roommemory "instant_share/server/internal/adapter/room/memory"
	gatewaysvc "instant_share/server/internal/application/gateway/service"
	roomsvc "instant_share/server/internal/application/room/service"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/config"
	"instant_share/server/internal/delivery"
	"instant_share/server/internal/interfaces/gateway"
	publicif "instant_share/server/internal/interfaces/public"
	roomif "instant_share/server/internal/interfaces/room"
	shareif "instant_share/server/internal/interfaces/share"
	"instant_share/server/internal/interfaces/system"
	infraws "instant_share/server/internal/infrastructure/websocket"
	"net/http"
)

// Bootstrap 装配 HTTP 处理器与依赖。
func Bootstrap(cfg config.Config) (http.Handler, *AppDeps, func(), error) {
	wsClient := infraws.NewClient(cfg.WebSocket)

	shareStore := sharememory.NewStore(cfg.Port)
	shareSvc := sharesvc.NewService(shareStore, cfg.Host, cfg.Port)

	roomSvc := roomsvc.NewService()
	mirrorStore := roommemory.NewPublicMirror()
	mirrorSvc := roomsvc.NewMirrorService(mirrorStore)

	roomWS := roomif.NewWSController(roomSvc, mirrorSvc, wsClient)
	roomWS.Register(wsClient)

	shareWS := shareif.NewWSController(shareSvc, roomSvc, mirrorSvc, wsClient)
	shareWS.SetRoomSyncer(roomWS)
	shareWS.Register(wsClient)

	authSvc := gatewaysvc.NewAuthenticate()
	gatewayCtrl := gateway.NewController(wsClient)
	gatewayCtrl.SetAuthFunc(authSvc.Authenticate)

	systemCtrl := system.NewController(shareSvc, cfg)
	publicCtrl := publicif.NewController(shareSvc, roomSvc, mirrorSvc)

	roomSvc.SetHooks(
		func() {
			roomWS.BroadcastCatalogUpdated()
			shareWS.BroadcastShareStatus()
		},
		func() {
			roomWS.BroadcastPendingUpdated()
		},
	)

	mux := delivery.RegistrationRoutes(systemCtrl, gatewayCtrl, publicCtrl)

	deps := &AppDeps{
		Config: cfg,
		Share:  shareSvc,
		Room:   roomSvc,
		Mirror: mirrorSvc,
		WS:     wsClient,
		RoomWS: roomWS,
	}

	cleanup := func() {
		roomWS.Stop()
	}

	return mux, deps, cleanup, nil
}
