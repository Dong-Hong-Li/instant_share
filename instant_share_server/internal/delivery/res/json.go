// Package res HTTP JSON 响应封装（ok/message/data 统一结构）。
package res

import (
	"encoding/json"
	"net/http"
)

// APIResponse 通用 JSON 响应 envelope。
type APIResponse struct {
	OK      bool   `json:"ok"`
	Message string `json:"message,omitempty"` // 失败时人类可读说明
	Data    any    `json:"data,omitempty"`      // 成功时业务载荷
}

// WriteJSON 写入 JSON 响应并设置 Content-Type。
func WriteJSON(w http.ResponseWriter, status int, payload APIResponse) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

// WriteError 写入 ok=false 的错误 JSON。
func WriteError(w http.ResponseWriter, status int, message string) {
	WriteJSON(w, status, APIResponse{
		OK:      false,
		Message: message,
	})
}

// MethodNotAllowed 返回 HTTP 405 与统一 JSON 错误体。
func MethodNotAllowed(w http.ResponseWriter) {
	WriteError(w, http.StatusMethodNotAllowed, "method not allowed")
}
