package handler

import (
	"context"
	"encoding/json"
	"errors"

	"instant_share/server/internal/infrastructure/websocket"
	"instant_share/server/internal/model"
	"instant_share/server/internal/service"
)

// WSAdminHandler admin WebSocket：仅 share.start / share.stop。
type WSAdminHandler struct {
	share *service.ShareService
}

func NewWSAdminHandler(share *service.ShareService) *WSAdminHandler {
	return &WSAdminHandler{share: share}
}

func (h *WSAdminHandler) Register(client *websocket.Client) {
	client.SetAuthFunc(h.authenticate)
	client.RegisterHandler("share.start", h.handleShareStart)
	client.RegisterHandler("share.stop", h.handleShareStop)
}

func (h *WSAdminHandler) authenticate(_ context.Context, req websocket.AuthRequest) (string, string, error) {
	return websocket.DefaultAuth(context.Background(), req)
}

func (h *WSAdminHandler) handleShareStart(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("share.start_ack", packet.RequestID, websocket.CodeForbidden, "admin only"))
	}

	var req model.StartShareRequest
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(websocket.Error("share.start_ack", packet.RequestID, websocket.CodeBadRequest, "invalid request data"))
		}
	}

	status, err := h.share.Start(req)
	if err != nil {
		code := websocket.CodeBadRequest
		switch {
		case errors.Is(err, service.ErrShareActive):
			code = websocket.CodeConflict
		case errors.Is(err, service.ErrNoFiles):
			code = websocket.CodeBadRequest
		}
		return conn.WriteResponse(websocket.Error("share.start_ack", packet.RequestID, code, err.Error()))
	}
	return conn.WriteResponse(websocket.Success("share.start_ack", packet.RequestID, status))
}

func (h *WSAdminHandler) handleShareStop(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("share.stop_ack", packet.RequestID, websocket.CodeForbidden, "admin only"))
	}

	status, err := h.share.Stop()
	if err != nil {
		code := websocket.CodeConflict
		if !errors.Is(err, service.ErrShareNotActive) {
			code = websocket.CodeBadRequest
		}
		return conn.WriteResponse(websocket.Error("share.stop_ack", packet.RequestID, code, err.Error()))
	}
	return conn.WriteResponse(websocket.Success("share.stop_ack", packet.RequestID, status))
}
