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
	share  *service.ShareService
	ws     *websocket.Client
	wsRoom *WSRoomHandler
	room   *service.RoomService
	mirror *service.PublicRoomCatalog
}

// NewWSAdminHandler。
func NewWSAdminHandler(share *service.ShareService, ws *websocket.Client, wsRoom *WSRoomHandler, room *service.RoomService, mirror *service.PublicRoomCatalog) *WSAdminHandler {
	return &WSAdminHandler{share: share, ws: ws, wsRoom: wsRoom, room: room, mirror: mirror}
}

// Register 注册路由。
func (h *WSAdminHandler) Register(client *websocket.Client) {
	client.SetAuthFunc(h.authenticate)
	client.RegisterHandler("share.start", h.handleShareStart)
	client.RegisterHandler("share.stop", h.handleShareStop)
	client.RegisterHandler("share.sync", h.handleShareSync)
	client.RegisterHandler("share.article.sync", h.handleShareArticleSync)
	client.RegisterHandler("room.public_catalog.sync", h.handlePublicCatalogSync)
	client.RegisterHandler("room.public_catalog.clear", h.handlePublicCatalogClear)
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

	// 同步 Host 目录（仅当本节点为真正的 Host、镜像为空时才会写入 RoomService，见
	// SyncHostCatalog 的早退保护）。此处不再无条件清空 Peer 镜像——否则 Peer 一旦开始本地
	// 分享，就会丢掉它作为 Peer 聚合到的完整跨设备目录（A+B…），导致其 /share 只剩本机文件。
	if h.wsRoom != nil {
		h.wsRoom.SyncHostCatalog(status)
	}
	h.broadcastShareStatus()
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

	// 先关闭房间（清空 RoomService 目录）并清空 Peer 镜像目录，再广播状态：CloseRoom 会让
	// isRoomHost 变为 false，若不同时清空镜像，残留的旧 Peer 镜像会在此时抢先顶替空房间目录，
	// 让 viewer 收到「已停止分享但仍带旧镜像文件、active=true」的过期状态。
	if h.wsRoom != nil {
		h.wsRoom.CloseRoom()
	}
	if h.mirror != nil {
		h.mirror.Clear()
	}
	h.broadcastShareStatus()
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
	if h.wsRoom != nil {
		h.wsRoom.SyncHostCatalog(status)
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

// BroadcastShareStatus 对外导出：供房间目录变更（catalog_updated）等外部事件触发广播。
func (h *WSAdminHandler) BroadcastShareStatus() {
	h.broadcastShareStatus()
}

// broadcastShareStatus。
func (h *WSAdminHandler) broadcastShareStatus() {
	if h.ws == nil {
		return
	}
	public := h.buildPublicStatus()
	h.ws.BroadcastToRole(websocket.RoleViewer, websocket.Success("share.status", "", public))
}

// pushShareStatus。
func (h *WSAdminHandler) pushShareStatus(conn *websocket.Connection) {
	public := h.buildPublicStatus()
	_ = conn.WriteResponse(websocket.Success("share.status", "", public))
}

// buildPublicStatus 合并本机分享状态、房间目录与 Peer 镜像目录。
func (h *WSAdminHandler) buildPublicStatus() model.PublicShareStatus {
	status := h.share.Status()
	var catalog []model.SharedEntry
	if h.room != nil {
		catalog, _ = h.room.Catalog()
	}
	var mirror []model.SharedEntry
	if h.mirror != nil && !isRoomHost(h.room) {
		mirror = h.mirror.Entries()
	}
	return buildPublicShareStatus(status, catalog, mirror, resolveLocalBaseURL(h.room, h.share))
}

// publicCatalogSyncRequest Peer 镜像同步请求（Peer 侧接收房间目录后，将其作为镜像上报给自身 admin，
// 以便本机对外的 /share 页面也能展示完整跨设备目录）。
type publicCatalogSyncRequest struct {
	Catalog []model.SharedEntry `json:"catalog"`
}

// handlePublicCatalogSync。
func (h *WSAdminHandler) handlePublicCatalogSync(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("room.public_catalog.sync_ack", packet.RequestID, websocket.CodeForbidden, "admin only"))
	}

	// req。
	var req publicCatalogSyncRequest
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(websocket.Error("room.public_catalog.sync_ack", packet.RequestID, websocket.CodeBadRequest, "invalid request data"))
		}
	}

	if h.mirror != nil {
		h.mirror.Set(req.Catalog)
	}
	h.broadcastShareStatus()
	return conn.WriteResponse(websocket.Success("room.public_catalog.sync_ack", packet.RequestID, nil))
}

// handlePublicCatalogClear。
func (h *WSAdminHandler) handlePublicCatalogClear(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("room.public_catalog.clear_ack", packet.RequestID, websocket.CodeForbidden, "admin only"))
	}

	if h.mirror != nil {
		h.mirror.Clear()
	}
	h.broadcastShareStatus()
	return conn.WriteResponse(websocket.Success("room.public_catalog.clear_ack", packet.RequestID, nil))
}
