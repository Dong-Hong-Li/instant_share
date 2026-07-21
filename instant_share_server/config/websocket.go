package config

import "time"

// WebSocketConfig WebSocket 运行参数。
type WebSocketConfig struct {
	ReadBufferSize  int
	WriteBufferSize int
	ReadLimit       int64
	AuthTimeoutSec  int
	PongWaitSec     int
	WriteWaitSec    int
}

// DefaultWebSocketConfig 返回默认 WebSocket 配置。
func DefaultWebSocketConfig() WebSocketConfig {
	return WebSocketConfig{
		ReadBufferSize:  4096,
		WriteBufferSize: 4096,
		ReadLimit:       1 << 20,
		AuthTimeoutSec:  10,
		PongWaitSec:     60,
		WriteWaitSec:    10,
	}
}

// AuthTimeout 鉴权超时时间。
func (c WebSocketConfig) AuthTimeout() time.Duration {
	return time.Duration(c.AuthTimeoutSec) * time.Second
}

// PongWait Pong 等待时间。
func (c WebSocketConfig) PongWait() time.Duration {
	return time.Duration(c.PongWaitSec) * time.Second
}

// WriteWait 写入超时时间。
func (c WebSocketConfig) WriteWait() time.Duration {
	return time.Duration(c.WriteWaitSec) * time.Second
}
