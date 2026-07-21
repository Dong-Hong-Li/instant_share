package cmd

import (
	roomsvc "instant_share/server/internal/application/room/service"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/config"
	roomif "instant_share/server/internal/interfaces/room"
	infraws "instant_share/server/internal/infrastructure/websocket"
)

// AppDeps 运行时依赖集合。
type AppDeps struct {
	Config config.Config
	Share  *sharesvc.Service
	Room   *roomsvc.Service
	Mirror *roomsvc.MirrorService
	WS     *infraws.Client
	RoomWS *roomif.WSController
}
