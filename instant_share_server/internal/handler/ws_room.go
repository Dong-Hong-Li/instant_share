package handler

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"sync"
	"time"

	"instant_share/server/internal/infrastructure/websocket"
	"instant_share/server/internal/model"
	"instant_share/server/internal/service"
)

// WSRoomHandler。
type WSRoomHandler struct {
	room   *service.RoomService
	ws     *websocket.Client
	mirror *service.PublicRoomCatalog

	mu         sync.RWMutex
	peerConns  map[string]*websocket.Connection
	authorized map[string]bool
	stopSweep  chan struct{}

	onCatalogUpdated func()
}

// NewWSRoomHandler。
func NewWSRoomHandler(room *service.RoomService, ws *websocket.Client) *WSRoomHandler {
	return &WSRoomHandler{
		room:       room,
		ws:         ws,
		peerConns:  make(map[string]*websocket.Connection),
		authorized: make(map[string]bool),
		stopSweep:  make(chan struct{}),
	}
}

// SetPublicMirror 注入 Peer 镜像目录，供 SyncHostCatalog 判定本节点是否为 Peer（镜像非空）。
func (h *WSRoomHandler) SetPublicMirror(mirror *service.PublicRoomCatalog) {
	h.mirror = mirror
}

// Register 注册路由。
func (h *WSRoomHandler) Register(client *websocket.Client) {
	client.RegisterHandler("pairing.request", h.handlePairingRequest)
	client.RegisterHandler("pairing.decide", h.handlePairingDecide)
	client.RegisterHandler("share.offer", h.handleShareOffer)
	client.RegisterHandler("room.snapshot", h.handleRoomSnapshot)
	client.RegisterHandler("room.leave", h.handleRoomLeave)
	client.SetConnectionHooks(h.handleConnect, h.handleDisconnect)
	go h.sweepExpired()
}

// handleConnect。
func (h *WSRoomHandler) handleConnect(role, _ string, deviceID string) {
	if role != websocket.RolePeer {
		return
	}
	if conn, ok := h.ws.GetConnection(deviceID, deviceID); ok {
		h.mu.Lock()
		h.peerConns[deviceID] = conn
		h.authorized[deviceID] = h.room.IsAuthorizedPeer(deviceID)
		h.mu.Unlock()
	}
}

// handleDisconnect。
func (h *WSRoomHandler) handleDisconnect(role, _ string, deviceID string) {
	if role != websocket.RolePeer {
		return
	}
	h.mu.Lock()
	delete(h.peerConns, deviceID)
	delete(h.authorized, deviceID)
	h.mu.Unlock()
}

// handlePairingRequest。
func (h *WSRoomHandler) handlePairingRequest(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RolePeer {
		return conn.WriteResponse(websocket.Error("pairing.request_ack", packet.RequestID, websocket.CodeForbidden, "peer only"))
	}

	// req。
	var req struct {
		DeviceID    string `json:"device_id"`
		DisplayName string `json:"display_name"`
		PeerBaseURL string `json:"peer_base_url"`
	}
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(websocket.Error("pairing.request_ack", packet.RequestID, websocket.CodeBadRequest, "invalid request data"))
		}
	}
	if req.DeviceID == "" {
		req.DeviceID = conn.DeviceID()
	}
	if req.DeviceID != conn.DeviceID() {
		return conn.WriteResponse(websocket.Error("pairing.request_ack", packet.RequestID, websocket.CodeForbidden, "device_id mismatch"))
	}

	pending, err := h.room.RequestPairing(req.DeviceID, req.DisplayName, req.PeerBaseURL)
	if err != nil {
		return conn.WriteResponse(websocket.Error("pairing.request_ack", packet.RequestID, roomErrorCode(err), err.Error()))
	}

	h.mu.Lock()
	h.peerConns[conn.DeviceID()] = conn
	h.authorized[conn.DeviceID()] = false
	h.mu.Unlock()
	h.broadcastPendingUpdated()
	return conn.WriteResponse(websocket.Success("pairing.request_ack", packet.RequestID, pending))
}

// handlePairingDecide。
func (h *WSRoomHandler) handlePairingDecide(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("pairing.decide_ack", packet.RequestID, websocket.CodeForbidden, "admin only"))
	}

	// req。
	var req struct {
		DeviceID string `json:"device_id"`
		Approve  bool   `json:"approve"`
	}
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(websocket.Error("pairing.decide_ack", packet.RequestID, websocket.CodeBadRequest, "invalid request data"))
		}
	}
	if req.DeviceID == "" {
		return conn.WriteResponse(websocket.Error("pairing.decide_ack", packet.RequestID, websocket.CodeBadRequest, "device_id required"))
	}

	if req.Approve {
		member, err := h.room.Approve(req.DeviceID)
		if err != nil {
			return conn.WriteResponse(websocket.Error("pairing.decide_ack", packet.RequestID, roomErrorCode(err), err.Error()))
		}
		h.mu.Lock()
		h.authorized[req.DeviceID] = true
		peerConn := h.peerConns[req.DeviceID]
		h.mu.Unlock()
		data := map[string]any{
			"room_id":       h.room.RoomID(),
			"host_base_url": h.room.HostBaseURL(),
			"member":        member,
		}
		if peerConn != nil {
			_ = peerConn.WriteResponse(websocket.Success("pairing.approve", "", data))
		}
		h.broadcastCatalogUpdated()
		h.broadcastPendingUpdated()
		return conn.WriteResponse(websocket.Success("pairing.decide_ack", packet.RequestID, map[string]any{
			"member": member,
		}))
	}

	if err := h.room.Reject(req.DeviceID); err != nil {
		return conn.WriteResponse(websocket.Error("pairing.decide_ack", packet.RequestID, roomErrorCode(err), err.Error()))
	}
	h.mu.Lock()
	peerConn := h.peerConns[req.DeviceID]
	h.authorized[req.DeviceID] = false
	h.mu.Unlock()
	if peerConn != nil {
		_ = peerConn.WriteResponse(websocket.Success("pairing.reject", "", nil))
	}
	h.broadcastPendingUpdated()
	return conn.WriteResponse(websocket.Success("pairing.decide_ack", packet.RequestID, nil))
}

// handleRoomLeave Peer 主动离房：移除成员、清理其目录并通知 Host。
func (h *WSRoomHandler) handleRoomLeave(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RolePeer {
		return conn.WriteResponse(websocket.Error("room.leave_ack", packet.RequestID, websocket.CodeForbidden, "peer only"))
	}

	deviceID := conn.DeviceID()
	_, _, removed := h.room.RemoveMember(deviceID)
	h.mu.Lock()
	delete(h.peerConns, deviceID)
	delete(h.authorized, deviceID)
	h.mu.Unlock()

	if removed {
		h.broadcastCatalogUpdated()
	}
	return conn.WriteResponse(websocket.Success("room.leave_ack", packet.RequestID, nil))
}

// handleShareOffer。
func (h *WSRoomHandler) handleShareOffer(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() != websocket.RolePeer {
		return conn.WriteResponse(websocket.Error("share.offer_ack", packet.RequestID, websocket.CodeForbidden, "peer only"))
	}
	if !h.isAuthorized(conn.DeviceID()) {
		return conn.WriteResponse(websocket.Error("share.offer_ack", packet.RequestID, websocket.CodeForbidden, "peer not approved"))
	}

	// req。
	var req struct {
		OwnerID  string                 `json:"owner_id"`
		BaseURL  string                 `json:"base_url"`
		Files    []model.SharedFileMeta `json:"files"`
		Revision int                    `json:"revision"`
	}
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(websocket.Error("share.offer_ack", packet.RequestID, websocket.CodeBadRequest, "invalid request data"))
		}
	}
	if req.OwnerID != conn.DeviceID() {
		return conn.WriteResponse(websocket.Error("share.offer_ack", packet.RequestID, websocket.CodeForbidden, "owner_id mismatch"))
	}
	member, ok := h.room.Member(req.OwnerID)
	if !ok {
		return conn.WriteResponse(websocket.Error("share.offer_ack", packet.RequestID, websocket.CodeForbidden, "peer not approved"))
	}
	if req.BaseURL != member.PeerBaseURL {
		return conn.WriteResponse(websocket.Error("share.offer_ack", packet.RequestID, websocket.CodeForbidden, "base_url mismatch"))
	}

	catalog, revision := h.room.SetOwnerFiles(req.OwnerID, member.DisplayName, req.BaseURL, req.Files)
	h.broadcastCatalogUpdated()
	return conn.WriteResponse(websocket.Success("share.offer_ack", packet.RequestID, map[string]any{
		"catalog":  catalog,
		"revision": revision,
	}))
}

// handleRoomSnapshot。
func (h *WSRoomHandler) handleRoomSnapshot(_ context.Context, conn *websocket.Connection, _ []byte, packet websocket.Packet) error {
	if conn.Role() == websocket.RolePeer && !h.isAuthorized(conn.DeviceID()) {
		return conn.WriteResponse(websocket.Error("room.snapshot_ack", packet.RequestID, websocket.CodeForbidden, "peer not approved"))
	}
	if conn.Role() != websocket.RolePeer && conn.Role() != websocket.RoleAdmin {
		return conn.WriteResponse(websocket.Error("room.snapshot_ack", packet.RequestID, websocket.CodeForbidden, "admin or peer only"))
	}

	catalog, revision := h.room.Catalog()
	data := map[string]any{
		"catalog":  catalog,
		"revision": revision,
		"members":  h.room.Members(),
	}
	if conn.Role() == websocket.RoleAdmin {
		data["pending"] = h.room.Pending()
	}
	return conn.WriteResponse(websocket.Success("room.snapshot_ack", packet.RequestID, data))
}

// SyncHostCatalog。
func (h *WSRoomHandler) SyncHostCatalog(status model.ShareStatus) {
	if !status.Active {
		return
	}
	// 若本节点持有非空 Peer 镜像目录，说明它正作为 Peer 镜像某个远端 Host 的聚合目录；
	// 此时本机开始本地分享不应把自己晋升为 RoomService 的 "host"（否则会污染房间目录、
	// 让 isRoomHost 误判并丢失 Peer 聚合到的完整目录）。镜像为空时（真正的 Host）才继续。
	if h.mirror != nil && len(h.mirror.Entries()) > 0 {
		return
	}
	hostBaseURL := status.BaseURL
	if len(hostBaseURL) >= len("/share") && hostBaseURL[len(hostBaseURL)-len("/share"):] == "/share" {
		hostBaseURL = hostBaseURL[:len(hostBaseURL)-len("/share")]
	}
	files := make([]model.SharedFileMeta, 0, len(status.Files))
	for _, file := range status.Files {
		files = append(files, model.SharedFileMeta{
			ID:           file.ID,
			Name:         file.Name,
			Size:         file.Size,
			DownloadPath: "/api/v1/share/files/" + file.ID + "/download",
		})
	}
	h.room.EnsureRoom("host", hostBaseURL, status.SessionID)
	h.room.SetOwnerFiles("host", "Host", hostBaseURL, files)
	h.broadcastCatalogUpdated()
}

// CloseRoom。
func (h *WSRoomHandler) CloseRoom() {
	h.room.Close()
	h.mu.Lock()
	peers := make([]*websocket.Connection, 0, len(h.peerConns))
	for _, conn := range h.peerConns {
		peers = append(peers, conn)
	}
	h.peerConns = make(map[string]*websocket.Connection)
	h.authorized = make(map[string]bool)
	h.mu.Unlock()

	notice := websocket.Success("room.notify", "", map[string]any{"event": "room_closed"})
	for _, conn := range peers {
		_ = conn.WriteResponse(notice)
		_ = conn.Close()
	}
	h.broadcastPendingUpdated()
}

// isAuthorized。
func (h *WSRoomHandler) isAuthorized(deviceID string) bool {
	h.mu.RLock()
	authorized := h.authorized[deviceID]
	h.mu.RUnlock()
	return authorized || h.room.IsAuthorizedPeer(deviceID)
}

// SetOnCatalogUpdated 注册房间目录变更回调（如触发 WSAdminHandler 广播 share.status）。
func (h *WSRoomHandler) SetOnCatalogUpdated(fn func()) {
	h.onCatalogUpdated = fn
}

// broadcastCatalogUpdated。
func (h *WSRoomHandler) broadcastCatalogUpdated() {
	catalog, revision := h.room.Catalog()
	notice := websocket.Success("room.notify", "", map[string]any{
		"event":    "catalog_updated",
		"catalog":  catalog,
		"members":  h.room.Members(),
		"revision": revision,
	})
	h.ws.BroadcastToRole(websocket.RolePeer, notice)
	h.ws.BroadcastToRole(websocket.RoleAdmin, notice)
	if h.onCatalogUpdated != nil {
		h.onCatalogUpdated()
	}
}

// broadcastPendingUpdated。
func (h *WSRoomHandler) broadcastPendingUpdated() {
	notice := websocket.Success("room.notify", "", map[string]any{
		"event":   "pending_updated",
		"pending": h.room.Pending(),
		"members": h.room.Members(),
	})
	h.ws.BroadcastToRole(websocket.RoleAdmin, notice)
}

// sweepExpired。
func (h *WSRoomHandler) sweepExpired() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			expired := h.room.SweepExpired()
			if len(expired) == 0 {
				continue
			}
			for _, deviceID := range expired {
				h.mu.RLock()
				conn := h.peerConns[deviceID]
				h.mu.RUnlock()
				if conn != nil {
					_ = conn.WriteResponse(websocket.Success("pairing.timeout", "", nil))
				}
			}
			h.broadcastPendingUpdated()
		case <-h.stopSweep:
			return
		}
	}
}

// roomErrorCode。
func roomErrorCode(err error) int {
	switch {
	case errors.Is(err, service.ErrRoomNotActive):
		return websocket.CodeConflict
	case errors.Is(err, service.ErrPairingNotFound):
		return websocket.CodeNotFound
	case errors.Is(err, service.ErrPairingExpired):
		return websocket.CodeConflict
	case errors.Is(err, service.ErrInvalidRoomArgument):
		return websocket.CodeBadRequest
	default:
		log.Printf("[ws-room] unexpected error: %v", err)
		return websocket.CodeBadRequest
	}
}
