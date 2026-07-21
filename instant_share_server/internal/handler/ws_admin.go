package handler

import (
	"context"
	"encoding/json"
	"errors"

	"instant_share/server/internal/infrastructure/websocket"
	"instant_share/server/internal/model"
	"instant_share/server/internal/service"
)

// WSAdminHandler admin WebSocket：分享启停与文件列表同步。
type WSAdminHandler struct {
	share *service.ShareService
	ws    *websocket.Client
	room  *WSRoomHandler
}

// NewWSAdminHandler。
func NewWSAdminHandler(share *service.ShareService, ws *websocket.Client, room *WSRoomHandler) *WSAdminHandler {
	return &WSAdminHandler{share: share, ws: ws, room: room}
}

// Register 注册路由。
func (h *WSAdminHandler) Register(client *websocket.Client) {
	client.SetAuthFunc(h.authenticate)
	client.RegisterHandler("share.start", h.handleShareStart)
	client.RegisterHandler("share.stop", h.handleShareStop)
	client.RegisterHandler("share.sync", h.handleShareSync)
	client.RegisterHandler("share.article.sync", h.handleShareArticleSync)
	client.SetViewerConnectHook(h.handleViewerConnect)
}

// authenticate 处理连接鉴权。
func (h *WSAdminHandler) authenticate(_ context.Context, req websocket.AuthRequest) (string, string, error) {
	return websocket.DefaultAuth(context.Background(), req)
}

// handleViewerConnect。
func (h *WSAdminHandler) handleViewerConnect(conn *websocket.Connection) {
	h.pushShareStatus(conn)
}

// handleShareStart。
func (h *WSAdminHandler) handleShareStart(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("share.start_ack", packet.RequestID, websocket.CodeForbidden, "admin only"))
	}

	// req。
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

	h.broadcastShareStatus()
	if h.room != nil {
		h.room.SyncHostCatalog(status)
	}
	return conn.WriteResponse(websocket.Success("share.start_ack", packet.RequestID, status))
}

// handleShareStop。
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

	h.broadcastShareStatus()
	if h.room != nil {
		h.room.CloseRoom()
	}
	return conn.WriteResponse(websocket.Success("share.stop_ack", packet.RequestID, status))
}

// handleShareSync。
func (h *WSAdminHandler) handleShareSync(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("share.sync_ack", packet.RequestID, websocket.CodeForbidden, "admin only"))
	}

	// req。
	var req model.StartShareRequest
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(websocket.Error("share.sync_ack", packet.RequestID, websocket.CodeBadRequest, "invalid request data"))
		}
	}

	status, err := h.share.SyncFiles(req.Files)
	if err != nil {
		code := websocket.CodeBadRequest
		switch {
		case errors.Is(err, service.ErrShareNotActive):
			code = websocket.CodeConflict
		case errors.Is(err, service.ErrNoFiles):
			code = websocket.CodeBadRequest
		}
		return conn.WriteResponse(websocket.Error("share.sync_ack", packet.RequestID, code, err.Error()))
	}

	h.broadcastShareStatus()
	if h.room != nil {
		h.room.SyncHostCatalog(status)
	}
	return conn.WriteResponse(websocket.Success("share.sync_ack", packet.RequestID, status))
}

// handleShareArticleSync。
func (h *WSAdminHandler) handleShareArticleSync(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("share.article.sync_ack", packet.RequestID, websocket.CodeForbidden, "admin only"))
	}

	// req。
	var req model.SyncArticleRequest
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(websocket.Error("share.article.sync_ack", packet.RequestID, websocket.CodeBadRequest, "invalid request data"))
		}
	}

	status, err := h.share.SyncArticles(req.Articles)
	if err != nil {
		code := websocket.CodeBadRequest
		if errors.Is(err, service.ErrShareNotActive) {
			code = websocket.CodeConflict
		}
		return conn.WriteResponse(websocket.Error("share.article.sync_ack", packet.RequestID, code, err.Error()))
	}

	h.broadcastShareStatus()
	return conn.WriteResponse(websocket.Success("share.article.sync_ack", packet.RequestID, status))
}

// broadcastShareStatus。
func (h *WSAdminHandler) broadcastShareStatus() {
	if h.ws == nil {
		return
	}
	public := toPublicShareStatus(h.share.Status())
	h.ws.BroadcastToRole(websocket.RoleViewer, websocket.Success("share.status", "", public))
}

// pushShareStatus。
func (h *WSAdminHandler) pushShareStatus(conn *websocket.Connection) {
	public := toPublicShareStatus(h.share.Status())
	_ = conn.WriteResponse(websocket.Success("share.status", "", public))
}
