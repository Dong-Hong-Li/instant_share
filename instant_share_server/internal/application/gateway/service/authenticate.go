// Package service WebSocket 网关鉴权用例。
package service

import (
	"context"

	infraws "instant_share/server/internal/infrastructure/websocket"
)

// Authenticate WebSocket 连接鉴权用例（委托 infrastructure 默认实现）。
type Authenticate struct{}

// NewAuthenticate 创建鉴权用例。
func NewAuthenticate() *Authenticate {
	return &Authenticate{}
}

/**
 * @description: Authenticate 校验握手 query（role/device_id/token），返回 role 与 deviceID。
 * @param {context.Context} ctx 请求上下文
 * @param {infraws.AuthRequest} req 握手参数
 * @return {string} role admin|peer|viewer
 * @return {string} deviceID 设备标识
 * @return {error} 鉴权失败
 */
func (a *Authenticate) Authenticate(ctx context.Context, req infraws.AuthRequest) (string, string, error) {
	return infraws.DefaultAuth(ctx, req)
}
