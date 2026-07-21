package handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"instant_share/server/config"
	"instant_share/server/internal/model"
	"instant_share/server/internal/service"
	"instant_share/server/internal/util"
)

// APIHandler 面向 Flutter admin 的 HTTP 接口。
type APIHandler struct {
	share  *service.ShareService
	config config.Config
}

// NewAPIHandler 创建 API 处理器。
func NewAPIHandler(share *service.ShareService, cfg config.Config) *APIHandler {
	return &APIHandler{share: share, config: cfg}
}

// Health 返回服务健康状态。
func (h *APIHandler) Health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, model.APIResponse{
		OK:   true,
		Data: map[string]string{"service": "instant-share-server"},
	})
}

// ServerHealth admin 探测：返回 WebSocket 地址与服务可用状态。
func (h *APIHandler) ServerHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}

	port := h.config.Port
	localIPs := util.LocalIPs()
	lanIP := localIPs[0]

	writeJSON(w, http.StatusOK, model.APIResponse{
		OK: true,
		Data: model.ServerHealth{
			Service:  "instant-share-server",
			Healthy:  true,
			Port:     port,
			LANIP:    lanIP,
			LocalIPs: localIPs,
			HTTPBase: fmt.Sprintf("http://127.0.0.1:%d", port),
			WSURL:    fmt.Sprintf("ws://127.0.0.1:%d/ws", port),
			ShareURL: fmt.Sprintf("http://%s:%d/share", lanIP, port),
			Share:    h.share.Status(),
		},
	})
}

// Status 返回分享状态。
func (h *APIHandler) Status(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, model.APIResponse{
		OK:   true,
		Data: h.share.Status(),
	})
}

// StartShare 开始分享。
func (h *APIHandler) StartShare(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}

	// req。
	var req model.StartShareRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	status, err := h.share.Start(req)
	if err != nil {
		writeShareError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, model.APIResponse{
		OK:   true,
		Data: status,
	})
}

// StopShare 停止分享。
func (h *APIHandler) StopShare(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}

	status, err := h.share.Stop()
	if err != nil {
		writeShareError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, model.APIResponse{
		OK:   true,
		Data: status,
	})
}

// writeShareError 写入分享错误。
func writeShareError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, service.ErrShareActive):
		writeError(w, http.StatusConflict, err.Error())
	case errors.Is(err, service.ErrShareNotActive):
		writeError(w, http.StatusConflict, err.Error())
	case errors.Is(err, service.ErrNoFiles):
		writeError(w, http.StatusBadRequest, err.Error())
	default:
		writeError(w, http.StatusBadRequest, err.Error())
	}
}

// writeError 写入错误响应。
func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, model.APIResponse{
		OK:      false,
		Message: message,
	})
}

// writeJSON 写入 JSON 响应。
func writeJSON(w http.ResponseWriter, status int, payload model.APIResponse) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

// methodNotAllowed 返回方法不允许。
func methodNotAllowed(w http.ResponseWriter) {
	writeError(w, http.StatusMethodNotAllowed, "method not allowed")
}
