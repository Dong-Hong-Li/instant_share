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
	// CodeSuccess。
	CodeSuccess = 0
	// CodeBadRequest。
	CodeBadRequest = 400
	// CodeUnauthorized。
	CodeUnauthorized = 401
	// CodeForbidden。
	CodeForbidden = 403
	// CodeNotFound。
	CodeNotFound = 404
	// CodeConflict。
	CodeConflict = 409
	CodeInternal = 500

	// RoleAdmin 发起者（谁启动 Go 服务 / Flutter 桌面端）。
	RoleAdmin = "admin"
	// RoleViewer 接收者（PC Web 浏览页，只读订阅分享状态）。
	RoleViewer = "viewer"
	// RolePeer 经 Host 审批后加入共享房间的 App 对端。
	RolePeer = "peer"
)

// Success。
func Success(packetType, requestID string, data any) Response {
	return Response{
		Type:      packetType,
		RequestID: requestID,
		Code:      CodeSuccess,
		Message:   "success",
		Data:      data,
	}
}

// Error。
func Error(packetType, requestID string, code int, message string) Response {
	return Response{
		Type:      packetType,
		RequestID: requestID,
		Code:      code,
		Message:   message,
	}
}
