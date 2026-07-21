package room

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"sync"
	"time"

	roomsvc "instant_share/server/internal/application/room/service"
	"instant_share/server/internal/domain/room"
	"instant_share/server/internal/domain/share"
	infraws "instant_share/server/internal/infrastructure/websocket"
	"instant_share/server/shared/consts"
)

// WSController 房间 WebSocket 控制器。
type WSController struct {
	room   *roomsvc.Service
	mirror *roomsvc.MirrorService
	ws     *infraws.Client

	mu         sync.RWMutex
	peerConns  map[string]*infraws.Connection
	authorized map[string]bool
	stopSweep  chan struct{}
}

// NewWSController 创建房间 WS 控制器。
func NewWSController(room *roomsvc.Service, mirror *roomsvc.MirrorService, ws *infraws.Client) *WSController {
	return &WSController{
		room:       room,
		mirror:     mirror,
		ws:         ws,
		peerConns:  make(map[string]*infraws.Connection),
		authorized: make(map[string]bool),
		stopSweep:  make(chan struct{}),
	}
}

// Register 注册 WS 处理器与连接钩子。
func (c *WSController) Register(client *infraws.Client) {
	client.RegisterHandler(consts.TypePairingRequest, c.handlePairingRequest)
	client.RegisterHandler(consts.TypePairingDecide, c.handlePairingDecide)
	client.RegisterHandler(consts.TypeShareOffer, c.handleShareOffer)
	client.RegisterHandler(consts.TypeRoomSnapshot, c.handleRoomSnapshot)
	client.RegisterHandler(consts.TypeRoomLeave, c.handleRoomLeave)
	client.SetConnectionHooks(c.handleConnect, c.handleDisconnect)
	go c.sweepExpired()
}

// Stop 停止后台 sweep goroutine。
func (c *WSController) Stop() {
	select {
	case <-c.stopSweep:
	default:
		close(c.stopSweep)
	}
}

func (c *WSController) handleConnect(role, _ string, deviceID string) {
	if role != infraws.RolePeer {
		return
	}
	if conn, ok := c.ws.GetConnection(deviceID, deviceID); ok {
		c.mu.Lock()
		c.peerConns[deviceID] = conn
		c.authorized[deviceID] = c.room.IsAuthorizedPeer(deviceID)
		c.mu.Unlock()
	}
}

func (c *WSController) handleDisconnect(role, _ string, deviceID string) {
	if role != infraws.RolePeer {
		return
	}
	c.mu.Lock()
	delete(c.peerConns, deviceID)
	delete(c.authorized, deviceID)
	c.mu.Unlock()
}

func (c *WSController) handlePairingRequest(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RolePeer {
		return conn.WriteResponse(infraws.Error(consts.TypePairingRequestAck, packet.RequestID, infraws.CodeForbidden, "peer only"))
	}

	var req struct {
		DeviceID    string `json:"device_id"`
		DisplayName string `json:"display_name"`
		PeerBaseURL string `json:"peer_base_url"`
	}
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(infraws.Error(consts.TypePairingRequestAck, packet.RequestID, infraws.CodeBadRequest, "invalid request data"))
		}
	}
	if req.DeviceID == "" {
		req.DeviceID = conn.DeviceID()
	}
	if req.DeviceID != conn.DeviceID() {
		return conn.WriteResponse(infraws.Error(consts.TypePairingRequestAck, packet.RequestID, infraws.CodeForbidden, "device_id mismatch"))
	}

	pending, err := c.room.RequestPairing(req.DeviceID, req.DisplayName, req.PeerBaseURL)
	if err != nil {
		return conn.WriteResponse(infraws.Error(consts.TypePairingRequestAck, packet.RequestID, roomErrorCode(err), err.Error()))
	}

	c.mu.Lock()
	c.peerConns[conn.DeviceID()] = conn
	c.authorized[conn.DeviceID()] = false
	c.mu.Unlock()
	c.room.NotifyPendingUpdated()
	return conn.WriteResponse(infraws.Success(consts.TypePairingRequestAck, packet.RequestID, pending))
}

func (c *WSController) handlePairingDecide(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RoleAdmin {
		return conn.WriteResponse(infraws.Error(consts.TypePairingDecideAck, packet.RequestID, infraws.CodeForbidden, "admin only"))
	}

	var req struct {
		DeviceID string `json:"device_id"`
		Approve  bool   `json:"approve"`
	}
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(infraws.Error(consts.TypePairingDecideAck, packet.RequestID, infraws.CodeBadRequest, "invalid request data"))
		}
	}
	if req.DeviceID == "" {
		return conn.WriteResponse(infraws.Error(consts.TypePairingDecideAck, packet.RequestID, infraws.CodeBadRequest, "device_id required"))
	}

	if req.Approve {
		member, err := c.room.Approve(req.DeviceID)
		if err != nil {
			return conn.WriteResponse(infraws.Error(consts.TypePairingDecideAck, packet.RequestID, roomErrorCode(err), err.Error()))
		}
		c.mu.Lock()
		c.authorized[req.DeviceID] = true
		peerConn := c.peerConns[req.DeviceID]
		c.mu.Unlock()
		data := map[string]any{
			"room_id":       c.room.RoomID(),
			"host_base_url": c.room.HostBaseURL(),
			"member":        member,
		}
		if peerConn != nil {
			_ = peerConn.WriteResponse(infraws.Success(consts.TypePairingApprove, "", data))
		}
		c.room.NotifyCatalogUpdated()
		c.room.NotifyPendingUpdated()
		return conn.WriteResponse(infraws.Success(consts.TypePairingDecideAck, packet.RequestID, map[string]any{
			"member": member,
		}))
	}

	if err := c.room.Reject(req.DeviceID); err != nil {
		return conn.WriteResponse(infraws.Error(consts.TypePairingDecideAck, packet.RequestID, roomErrorCode(err), err.Error()))
	}
	c.mu.Lock()
	peerConn := c.peerConns[req.DeviceID]
	c.authorized[req.DeviceID] = false
	c.mu.Unlock()
	if peerConn != nil {
		_ = peerConn.WriteResponse(infraws.Success(consts.TypePairingReject, "", nil))
	}
	c.room.NotifyPendingUpdated()
	return conn.WriteResponse(infraws.Success(consts.TypePairingDecideAck, packet.RequestID, nil))
}

func (c *WSController) handleRoomLeave(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RolePeer {
		return conn.WriteResponse(infraws.Error(consts.TypeRoomLeaveAck, packet.RequestID, infraws.CodeForbidden, "peer only"))
	}

	deviceID := conn.DeviceID()
	_, _, removed := c.room.RemoveMember(deviceID)
	c.mu.Lock()
	delete(c.peerConns, deviceID)
	delete(c.authorized, deviceID)
	c.mu.Unlock()

	if removed {
		c.room.NotifyCatalogUpdated()
	}
	return conn.WriteResponse(infraws.Success(consts.TypeRoomLeaveAck, packet.RequestID, nil))
}

func (c *WSController) handleShareOffer(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RolePeer {
		return conn.WriteResponse(infraws.Error(consts.TypeShareOfferAck, packet.RequestID, infraws.CodeForbidden, "peer only"))
	}
	if !c.isAuthorized(conn.DeviceID()) {
		return conn.WriteResponse(infraws.Error(consts.TypeShareOfferAck, packet.RequestID, infraws.CodeForbidden, "peer not approved"))
	}

	var req struct {
		OwnerID  string               `json:"owner_id"`
		BaseURL  string               `json:"base_url"`
		Files    []room.SharedFileMeta `json:"files"`
		Revision int                  `json:"revision"`
	}
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(infraws.Error(consts.TypeShareOfferAck, packet.RequestID, infraws.CodeBadRequest, "invalid request data"))
		}
	}
	if req.OwnerID != conn.DeviceID() {
		return conn.WriteResponse(infraws.Error(consts.TypeShareOfferAck, packet.RequestID, infraws.CodeForbidden, "owner_id mismatch"))
	}
	member, ok := c.room.Member(req.OwnerID)
	if !ok {
		return conn.WriteResponse(infraws.Error(consts.TypeShareOfferAck, packet.RequestID, infraws.CodeForbidden, "peer not approved"))
	}
	if req.BaseURL != member.PeerBaseURL {
		return conn.WriteResponse(infraws.Error(consts.TypeShareOfferAck, packet.RequestID, infraws.CodeForbidden, "base_url mismatch"))
	}

	catalog, revision := c.room.SetOwnerFiles(req.OwnerID, member.DisplayName, req.BaseURL, req.Files)
	c.room.NotifyCatalogUpdated()
	return conn.WriteResponse(infraws.Success(consts.TypeShareOfferAck, packet.RequestID, map[string]any{
		"catalog":  catalog,
		"revision": revision,
	}))
}

func (c *WSController) handleRoomSnapshot(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() == infraws.RolePeer && !c.isAuthorized(conn.DeviceID()) {
		return conn.WriteResponse(infraws.Error(consts.TypeRoomSnapshotAck, packet.RequestID, infraws.CodeForbidden, "peer not approved"))
	}
	if conn.Role() != infraws.RolePeer && conn.Role() != infraws.RoleAdmin {
		return conn.WriteResponse(infraws.Error(consts.TypeRoomSnapshotAck, packet.RequestID, infraws.CodeForbidden, "admin or peer only"))
	}

	catalog, revision := c.room.Catalog()
	data := map[string]any{
		"catalog":  catalog,
		"revision": revision,
		"members":  c.room.Members(),
	}
	if conn.Role() == infraws.RoleAdmin {
		data["pending"] = c.room.Pending()
	}
	return conn.WriteResponse(infraws.Success(consts.TypeRoomSnapshotAck, packet.RequestID, data))
}

// SyncHostCatalog 将本机分享状态同步到房间 Host 目录（Peer 镜像非空时早退）。
func (c *WSController) SyncHostCatalog(status share.Status) {
	if !status.Active {
		return
	}
	if c.mirror != nil && len(c.mirror.Entries()) > 0 {
		return
	}
	hostBaseURL := status.BaseURL
	if len(hostBaseURL) >= len("/share") && hostBaseURL[len(hostBaseURL)-len("/share"):] == "/share" {
		hostBaseURL = hostBaseURL[:len(hostBaseURL)-len("/share")]
	}
	files := make([]room.SharedFileMeta, 0, len(status.Files))
	for _, file := range status.Files {
		files = append(files, room.SharedFileMeta{
			ID:           file.ID,
			Name:         file.Name,
			Size:         file.Size,
			DownloadPath: "/api/v1/share/files/" + file.ID + "/download",
		})
	}
	c.room.EnsureRoom("host", hostBaseURL, status.SessionID)
	c.room.SetOwnerFiles("host", "Host", hostBaseURL, files)
	c.room.NotifyCatalogUpdated()
}

// CloseRoom 关闭房间并断开 Peer 连接。
func (c *WSController) CloseRoom() {
	c.room.Close()
	c.mu.Lock()
	peers := make([]*infraws.Connection, 0, len(c.peerConns))
	for _, conn := range c.peerConns {
		peers = append(peers, conn)
	}
	c.peerConns = make(map[string]*infraws.Connection)
	c.authorized = make(map[string]bool)
	c.mu.Unlock()

	notice := infraws.Success(consts.TypeRoomNotify, "", map[string]any{"event": "room_closed"})
	for _, conn := range peers {
		_ = conn.WriteResponse(notice)
		_ = conn.Close()
	}
	c.room.NotifyPendingUpdated()
}

func (c *WSController) isAuthorized(deviceID string) bool {
	c.mu.RLock()
	authorized := c.authorized[deviceID]
	c.mu.RUnlock()
	return authorized || c.room.IsAuthorizedPeer(deviceID)
}

// BroadcastCatalogUpdated 广播 room.notify catalog_updated（不含 share.status）。
func (c *WSController) BroadcastCatalogUpdated() {
	catalog, revision := c.room.Catalog()
	notice := infraws.Success(consts.TypeRoomNotify, "", map[string]any{
		"event":    "catalog_updated",
		"catalog":  catalog,
		"members":  c.room.Members(),
		"revision": revision,
	})
	c.ws.BroadcastToRole(infraws.RolePeer, notice)
	c.ws.BroadcastToRole(infraws.RoleAdmin, notice)
}

// BroadcastPendingUpdated 广播 room.notify pending_updated。
func (c *WSController) BroadcastPendingUpdated() {
	notice := infraws.Success(consts.TypeRoomNotify, "", map[string]any{
		"event":   "pending_updated",
		"pending": c.room.Pending(),
		"members": c.room.Members(),
	})
	c.ws.BroadcastToRole(infraws.RoleAdmin, notice)
}

func (c *WSController) sweepExpired() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			expired := c.room.SweepExpired()
			if len(expired) == 0 {
				continue
			}
			for _, deviceID := range expired {
				c.mu.RLock()
				conn := c.peerConns[deviceID]
				c.mu.RUnlock()
				if conn != nil {
					_ = conn.WriteResponse(infraws.Success(consts.TypePairingTimeout, "", nil))
				}
			}
			c.room.NotifyPendingUpdated()
		case <-c.stopSweep:
			return
		}
	}
}

func roomErrorCode(err error) int {
	switch {
	case errors.Is(err, room.ErrRoomNotActive):
		return infraws.CodeConflict
	case errors.Is(err, room.ErrPairingNotFound):
		return infraws.CodeNotFound
	case errors.Is(err, room.ErrPairingExpired):
		return infraws.CodeConflict
	case errors.Is(err, room.ErrInvalidRoomArgument):
		return infraws.CodeBadRequest
	default:
		log.Printf("[ws-room] unexpected error: %v", err)
		return infraws.CodeBadRequest
	}
}
