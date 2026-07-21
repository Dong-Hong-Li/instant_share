// Package cmd 提供服务装配与依赖容器（cmd/server、cmd/lib 与 runtime 共用）。
package cmd

import (
	"net/http"

	"instant_share/server/config"
	sharememory "instant_share/server/internal/adapter/share/memory"
	roommemory "instant_share/server/internal/adapter/room/memory"
	gatewaysvc "instant_share/server/internal/application/gateway/service"
	roomsvc "instant_share/server/internal/application/room/service"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/internal/delivery"
	infraws "instant_share/server/internal/infrastructure/websocket"
	"instant_share/server/internal/interfaces/gateway"
	publicif "instant_share/server/internal/interfaces/public"
	roomif "instant_share/server/internal/interfaces/room"
	shareif "instant_share/server/internal/interfaces/share"
	"instant_share/server/internal/interfaces/system"
)

/**
 * @description: Bootstrap 手写装配整站依赖并返回 HTTP Handler。
 * 顺序：infra(WS) → memory adapter → application → interfaces → 跨域 hooks → delivery 路由。
 * 跨域通知禁止 Controller 互 import：room catalog/pending 变更经 SetHooks 闭包转发到
 * roomWS 广播 room.notify，再由 shareWS 广播 viewer 的 share.status。
 * @param {config.Config} cfg 服务配置（Port 应为实际监听端口）
 * @return {http.Handler} HTTP 根处理器
 * @return {*AppDeps} 运行时依赖（Stop 时使用）
 * @return {func()} cleanup 释放后台 goroutine（如 room sweep）
 * @return {error} 装配错误（当前恒为 nil，预留扩展）
 */
func Bootstrap(cfg config.Config) (http.Handler, *AppDeps, func(), error) {
	/// ====== Infrastructure: WebSocket ======
	wsClient := infraws.NewClient(cfg.WebSocket)

	/// ====== Adapter + Application: share ======
	shareStore := sharememory.NewStore(cfg.Port)
	shareSvc := sharesvc.NewService(shareStore, cfg.Host, cfg.Port)

	/// ====== Adapter + Application: room ======
	roomSvc := roomsvc.NewService()
	mirrorStore := roommemory.NewPublicMirror()
	mirrorSvc := roomsvc.NewMirrorService(mirrorStore)

	/// ====== Interfaces: room WS（先创建，供 RoomCatalogSyncer 注入） ======
	roomWS := roomif.NewWSController(roomSvc, mirrorSvc, wsClient)
	roomWS.Register(wsClient)

	/// ====== Interfaces: share WS（经接口依赖 room，避免互 import） ======
	shareWS := shareif.NewWSController(shareSvc, roomSvc, mirrorSvc, wsClient)
	shareWS.SetRoomSyncer(roomWS)
	shareWS.Register(wsClient)

	/// ====== Interfaces: gateway / system / public ======
	authSvc := gatewaysvc.NewAuthenticate()
	gatewayCtrl := gateway.NewController(wsClient)
	gatewayCtrl.SetAuthFunc(authSvc.Authenticate)

	systemCtrl := system.NewController(shareSvc, cfg)
	publicCtrl := publicif.NewController(shareSvc, roomSvc, mirrorSvc)

	/// ====== Cross-context hooks（解耦 admin ↔ room） ======
	// catalog 变更：先 room.notify，再推 viewer share.status
	// pending 变更：仅通知 admin 侧 pending_updated
	roomSvc.SetHooks(
		func() {
			roomWS.BroadcastCatalogUpdated()
			shareWS.BroadcastShareStatus()
		},
		func() {
			roomWS.BroadcastPendingUpdated()
		},
	)

	/// ====== Delivery: 组装 HTTP 路由 ======
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
