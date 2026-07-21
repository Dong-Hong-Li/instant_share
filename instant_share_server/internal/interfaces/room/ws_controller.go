// Package room Peer/Admin WebSocket 入口：配对、成员目录、share.offer 与 room.notify。
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

// MemberDisconnectGrace 已入房 Peer 断线后保留成员的宽限期；超时踢出。
// 心跳失败触发断线后约 1s 踢出，避免 Host 列表长期残留离线成员。
var MemberDisconnectGrace = 1 * time.Second

// WSController 房间 WebSocket 控制器。
type WSController struct {
	room   *roomsvc.Service
	mirror *roomsvc.MirrorService
	ws     *infraws.Client

	mu               sync.RWMutex
	peerConns        map[string]*infraws.Connection // deviceID → 当前 Peer 连接
	authorized       map[string]bool                // 本进程内已审批标记（与 room 状态互补）
	disconnectTimers map[string]*time.Timer         // 断线踢人倒计时
	stopSweep        chan struct{}                  // 关闭 sweepExpired goroutine
}

// NewWSController 创建房间 WS 控制器。
func NewWSController(room *roomsvc.Service, mirror *roomsvc.MirrorService, ws *infraws.Client) *WSController {
	return &WSController{
		room:             room,
		mirror:           mirror,
		ws:               ws,
		peerConns:        make(map[string]*infraws.Connection),
		authorized:       make(map[string]bool),
		disconnectTimers: make(map[string]*time.Timer),
		stopSweep:        make(chan struct{}),
	}
}

/**
 * @description: Register 注册配对/目录/离房 WS 处理器，并启动 pending 过期 sweep。
 * @param {*infraws.Client} client WebSocket 基础设施客户端
 */
func (c *WSController) Register(client *infraws.Client) {
	client.RegisterHandler(consts.TypePairingRequest, c.handlePairingRequest)
	client.RegisterHandler(consts.TypePairingCancel, c.handlePairingCancel)
	client.RegisterHandler(consts.TypePairingDecide, c.handlePairingDecide)
	client.RegisterHandler(consts.TypeShareOffer, c.handleShareOffer)
	client.RegisterHandler(consts.TypeRoomSnapshot, c.handleRoomSnapshot)
	client.RegisterHandler(consts.TypeRoomLeave, c.handleRoomLeave)
	client.SetConnectionHooks(c.handleConnect, c.handleDisconnect)
	go c.sweepExpired()
}

// Stop 停止后台 sweep goroutine；进程退出前调用。
func (c *WSController) Stop() {
	c.cancelAllMemberRemovals()
	select {
	case <-c.stopSweep:
	default:
		close(c.stopSweep)
	}
}

// handleConnect Peer 连上时登记连接与授权快照；Admin/Viewer 忽略。
func (c *WSController) handleConnect(role, _ string, deviceID string) {
	if role != infraws.RolePeer {
		return
	}
	c.cancelMemberRemoval(deviceID)
	if conn, ok := c.ws.GetConnection(deviceID, deviceID); ok {
		c.mu.Lock()
		c.peerConns[deviceID] = conn
		c.authorized[deviceID] = c.room.IsAuthorizedPeer(deviceID)
		c.mu.Unlock()
	}
}

// handleDisconnect Peer 断开时清理本地连接表。
// 若仍在 pending（未入房），撤销申请，避免 Host 继续审批已取消/已离线的 Peer。
// 已入房成员：宽限期后踢出（短时重连可保留；关机/杀进程超时后 Host 列表更新）。
func (c *WSController) handleDisconnect(role, _ string, deviceID string) {
	if role != infraws.RolePeer {
		return
	}
	c.mu.Lock()
	delete(c.peerConns, deviceID)
	delete(c.authorized, deviceID)
	c.mu.Unlock()

	if err := c.room.Reject(deviceID); err == nil {
		c.room.NotifyPendingUpdated()
	}
	if c.room.IsAuthorizedPeer(deviceID) {
		c.scheduleMemberRemoval(deviceID)
	}
}

// handlePairingRequest Peer 提交配对；登记连接、NotifyPendingUpdated；写 pairing.request_ack。
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

	pending, rejoined, err := c.room.RequestPairing(req.DeviceID, req.DisplayName, req.PeerBaseURL)
	if err != nil {
		return conn.WriteResponse(infraws.Error(consts.TypePairingRequestAck, packet.RequestID, roomErrorCode(err), err.Error()))
	}

	c.cancelMemberRemoval(conn.DeviceID())
	c.mu.Lock()
	c.peerConns[conn.DeviceID()] = conn
	c.authorized[conn.DeviceID()] = rejoined
	c.mu.Unlock()

	// 宽限期内同 deviceID 再次申请：直接视为已入房，推送 approve，避免 Host 再审出重复成员。
	if rejoined {
		member := room.Member{
			DeviceID:    pending.DeviceID,
			DisplayName: pending.DisplayName,
			PeerBaseURL: pending.PeerBaseURL,
		}
		approveData := map[string]any{
			"room_id":       c.room.RoomID(),
			"host_base_url": c.room.HostBaseURL(),
			"member":        member,
		}
		_ = conn.WriteResponse(infraws.Success(consts.TypePairingApprove, "", approveData))
		c.room.NotifyCatalogUpdated()
		return conn.WriteResponse(infraws.Success(consts.TypePairingRequestAck, packet.RequestID, map[string]any{
			"rejoined":      true,
			"device_id":     pending.DeviceID,
			"display_name":  pending.DisplayName,
			"peer_base_url": pending.PeerBaseURL,
		}))
	}

	c.room.NotifyPendingUpdated()
	return conn.WriteResponse(infraws.Success(consts.TypePairingRequestAck, packet.RequestID, pending))
}

// handlePairingCancel Peer 主动撤回自己的待审批申请。
func (c *WSController) handlePairingCancel(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RolePeer {
		return conn.WriteResponse(infraws.Error(consts.TypePairingCancelAck, packet.RequestID, infraws.CodeForbidden, "peer only"))
	}
	deviceID := conn.DeviceID()
	if err := c.room.Reject(deviceID); err != nil {
		// 已不在 pending（重复取消 / 已审批）视为成功，避免取消流程卡死。
		if !errors.Is(err, room.ErrPairingNotFound) {
			return conn.WriteResponse(infraws.Error(consts.TypePairingCancelAck, packet.RequestID, roomErrorCode(err), err.Error()))
		}
	} else {
		c.room.NotifyPendingUpdated()
	}
	return conn.WriteResponse(infraws.Success(consts.TypePairingCancelAck, packet.RequestID, nil))
}

/**
 * @description: handlePairingDecide Admin 审批/拒绝配对。
 * 通过时向 Peer 推送 pairing.approve，并 NotifyCatalogUpdated + NotifyPendingUpdated。
 * @return {error} 写 pairing.decide_ack
 */
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

/**
 * @description: handleRoomLeave Peer 主动离房。
 * 移除成员后若目录变化则 NotifyCatalogUpdated；不广播 share.status。
 * @return {error} 写 room.leave_ack
 */
func (c *WSController) handleRoomLeave(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RolePeer {
		return conn.WriteResponse(infraws.Error(consts.TypeRoomLeaveAck, packet.RequestID, infraws.CodeForbidden, "peer only"))
	}

	deviceID := conn.DeviceID()
	c.cancelMemberRemoval(deviceID)
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

/**
 * @description: handleShareOffer 已审批 Peer 上报本机文件分片。
 * 校验 owner_id/base_url 与成员信息一致，更新聚合目录并 NotifyCatalogUpdated。
 * @return {error} 写 share.offer_ack
 */
func (c *WSController) handleShareOffer(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RolePeer {
		return conn.WriteResponse(infraws.Error(consts.TypeShareOfferAck, packet.RequestID, infraws.CodeForbidden, "peer only"))
	}
	if !c.isAuthorized(conn.DeviceID()) {
		return conn.WriteResponse(infraws.Error(consts.TypeShareOfferAck, packet.RequestID, infraws.CodeForbidden, "peer not approved"))
	}

	var req struct {
		OwnerID  string                `json:"owner_id"`
		BaseURL  string                `json:"base_url"`
		Files    []room.SharedFileMeta `json:"files"`
		Revision int                   `json:"revision"`
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

// handleRoomSnapshot Admin/已审批 Peer 拉取房间快照（catalog/members/pending）；写 room.snapshot_ack。
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

/**
 * @description: SyncHostCatalog 将本机分享状态同步到房间 Host 目录。
 * Peer 镜像非空时早退（镜像目录优先于 Host 本地文件）；否则写入 owner=host 并 NotifyCatalogUpdated。
 * @param {share.Status} status 本机分享快照
 */
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

/**
 * @description: CloseRoom 关闭房间并断开所有 Peer 连接。
 * 推送 room.notify room_closed，清空本地连接表，NotifyPendingUpdated。
 */
func (c *WSController) CloseRoom() {
	c.cancelAllMemberRemovals()
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

// scheduleMemberRemoval 断线后延迟踢出已入房成员。
func (c *WSController) scheduleMemberRemoval(deviceID string) {
	c.mu.Lock()
	if old, ok := c.disconnectTimers[deviceID]; ok {
		old.Stop()
	}
	c.disconnectTimers[deviceID] = time.AfterFunc(MemberDisconnectGrace, func() {
		c.mu.Lock()
		delete(c.disconnectTimers, deviceID)
		_, online := c.peerConns[deviceID]
		c.mu.Unlock()
		if online {
			return
		}
		if _, _, removed := c.room.RemoveMember(deviceID); removed {
			c.room.NotifyCatalogUpdated()
		}
	})
	c.mu.Unlock()
}

func (c *WSController) cancelMemberRemoval(deviceID string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if t, ok := c.disconnectTimers[deviceID]; ok {
		t.Stop()
		delete(c.disconnectTimers, deviceID)
	}
}

func (c *WSController) cancelAllMemberRemovals() {
	c.mu.Lock()
	defer c.mu.Unlock()
	for id, t := range c.disconnectTimers {
		t.Stop()
		delete(c.disconnectTimers, id)
	}
}

// isAuthorized 本进程授权标记或 room 持久成员态任一满足即视为已审批。
func (c *WSController) isAuthorized(deviceID string) bool {
	c.mu.RLock()
	authorized := c.authorized[deviceID]
	c.mu.RUnlock()
	return authorized || c.room.IsAuthorizedPeer(deviceID)
}

/**
 * @description: BroadcastCatalogUpdated 广播 room.notify catalog_updated。
 * 面向 Peer 与 Admin；不含 share.status（由 share WS 控制器负责）。
 */
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

/**
 * @description: BroadcastPendingUpdated 广播 room.notify pending_updated（仅 Admin）。
 * 不含 share.status。
 */
func (c *WSController) BroadcastPendingUpdated() {
	notice := infraws.Success(consts.TypeRoomNotify, "", map[string]any{
		"event":   "pending_updated",
		"pending": c.room.Pending(),
		"members": c.room.Members(),
	})
	c.ws.BroadcastToRole(infraws.RoleAdmin, notice)
}

// sweepExpired 定时清理过期 pending，向对应 Peer 推送 pairing.timeout 并 NotifyPendingUpdated。
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

// roomErrorCode 将 room 领域错误映射为 WS 业务码。
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
