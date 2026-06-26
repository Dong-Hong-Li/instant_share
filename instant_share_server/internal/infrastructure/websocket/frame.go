package websocket

import "encoding/json"

// AuthRequest WS 首帧 auth（仅 admin 使用 WebSocket）。
type AuthRequest struct {
	Type     string `json:"type" query:"type"`
	Role     string `json:"role" query:"role"`
	DeviceID string `json:"device_id" query:"device_id"`
}

// Packet 入站 WS 帧（type + request_id + data）。
type Packet struct {
	Type      string          `json:"type"`
	RequestID string          `json:"request_id,omitempty"`
	Data      json.RawMessage `json:"data,omitempty"`
}

// Response 出站 WS 帧（type + code + message + data）。
type Response struct {
	Type      string `json:"type"`
	RequestID string `json:"request_id,omitempty"`
	Code      int    `json:"code"`
	Message   string `json:"message"`
	Data      any    `json:"data,omitempty"`
}

const (
	CodeSuccess      = 0
	CodeBadRequest   = 400
	CodeUnauthorized = 401
	CodeForbidden    = 403
	CodeNotFound     = 404
	CodeConflict     = 409
	CodeInternal     = 500

	// RoleAdmin 发起者（谁启动 Go 服务 / Flutter 桌面端）。
	RoleAdmin = "admin"
)

func Success(packetType, requestID string, data any) Response {
	return Response{
		Type:      packetType,
		RequestID: requestID,
		Code:      CodeSuccess,
		Message:   "success",
		Data:      data,
	}
}

func Error(packetType, requestID string, code int, message string) Response {
	return Response{
		Type:      packetType,
		RequestID: requestID,
		Code:      code,
		Message:   message,
	}
}
