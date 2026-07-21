package cmd

import (
	roomsvc "instant_share/server/internal/application/room/service"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/config"
	roomif "instant_share/server/internal/interfaces/room"
	infraws "instant_share/server/internal/infrastructure/websocket"
)

// AppDeps 运行时依赖集合，供 runtime 启停与测试注入使用。
//
// 注意：RoomWS 仅用于优雅关闭（Stop sweep），业务侧禁止通过 AppDeps 让 Controller 互持。
type AppDeps struct {
	// Config 当前进程配置（含实际监听端口）。
	Config config.Config
	// Share 本机分享会话用例。
	Share *sharesvc.Service
	// Room 互享房间用例。
	Room *roomsvc.Service
	// Mirror Peer 侧公开目录镜像用例。
	Mirror *roomsvc.MirrorService
	// WS WebSocket 基础客户端（连接管理 / 广播）。
	WS *infraws.Client
	// RoomWS 房间 WS 控制器（仅生命周期清理）。
	RoomWS *roomif.WSController
}
