package service

import (
	"context"

	infraws "instant_share/server/internal/infrastructure/websocket"
)

// Authenticate WebSocket 连接鉴权用例。
type Authenticate struct{}

// NewAuthenticate 创建鉴权用例。
func NewAuthenticate() *Authenticate {
	return &Authenticate{}
}

// Authenticate 委托 infrastructure 默认鉴权。
func (a *Authenticate) Authenticate(ctx context.Context, req infraws.AuthRequest) (string, string, error) {
	return infraws.DefaultAuth(ctx, req)
}
