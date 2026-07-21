package share

import (
	"context"
	"encoding/json"
	"errors"

	roomsvc "instant_share/server/internal/application/room/service"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/internal/domain/room"
	"instant_share/server/internal/domain/share"
	infraws "instant_share/server/internal/infrastructure/websocket"
	"instant_share/server/internal/interfaces/request"
	"instant_share/server/shared/consts"
)

// RoomCatalogSyncer 房间目录同步回调（由 bootstrap 注入 room WS 控制器）。
type RoomCatalogSyncer interface {
	SyncHostCatalog(status share.Status)
	CloseRoom()
}

// WSController admin WebSocket：分享启停与文件列表同步。
type WSController struct {
	share      *sharesvc.Service
	room       *roomsvc.Service
	mirror     *roomsvc.MirrorService
	ws         *infraws.Client
	roomSyncer RoomCatalogSyncer
}

// NewWSController 创建分享 WS 控制器。
func NewWSController(
	share *sharesvc.Service,
	room *roomsvc.Service,
	mirror *roomsvc.MirrorService,
	ws *infraws.Client,
) *WSController {
	return &WSController{
		share:  share,
		room:   room,
		mirror: mirror,
		ws:     ws,
	}
}

// SetRoomSyncer 注入房间目录同步器。
func (c *WSController) SetRoomSyncer(syncer RoomCatalogSyncer) {
	c.roomSyncer = syncer
}

// Register 注册 WS 处理器。
func (c *WSController) Register(client *infraws.Client) {
	client.RegisterHandler(consts.TypeShareStart, c.handleShareStart)
	client.RegisterHandler(consts.TypeShareStop, c.handleShareStop)
	client.RegisterHandler(consts.TypeShareSync, c.handleShareSync)
	client.RegisterHandler(consts.TypeShareArticleSync, c.handleShareArticleSync)
	client.RegisterHandler(consts.TypePublicCatalogSync, c.handlePublicCatalogSync)
	client.RegisterHandler(consts.TypePublicCatalogClear, c.handlePublicCatalogClear)
	client.SetViewerConnectHook(c.handleViewerConnect)
}

func (c *WSController) handleViewerConnect(conn *infraws.Connection) {
	c.pushShareStatus(conn)
}

func (c *WSController) handleShareStart(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RoleAdmin {
		return conn.WriteResponse(infraws.Error(consts.TypeShareStartAck, packet.RequestID, infraws.CodeForbidden, "admin only"))
	}

	var req request.StartShareRequest
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(infraws.Error(consts.TypeShareStartAck, packet.RequestID, infraws.CodeBadRequest, "invalid request data"))
		}
	}

	status, err := c.share.Start(req.Files, req.Port)
	if err != nil {
		code := infraws.CodeBadRequest
		switch {
		case errors.Is(err, share.ErrShareActive):
			code = infraws.CodeConflict
		case errors.Is(err, share.ErrNoFiles):
			code = infraws.CodeBadRequest
		}
		return conn.WriteResponse(infraws.Error(consts.TypeShareStartAck, packet.RequestID, code, err.Error()))
	}

	if c.roomSyncer != nil {
		c.roomSyncer.SyncHostCatalog(status)
	}
	c.BroadcastShareStatus()
	return conn.WriteResponse(infraws.Success(consts.TypeShareStartAck, packet.RequestID, status))
}

func (c *WSController) handleShareStop(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RoleAdmin {
		return conn.WriteResponse(infraws.Error(consts.TypeShareStopAck, packet.RequestID, infraws.CodeForbidden, "admin only"))
	}

	status, err := c.share.Stop()
	if err != nil {
		code := infraws.CodeConflict
		if !errors.Is(err, share.ErrShareNotActive) {
			code = infraws.CodeBadRequest
		}
		return conn.WriteResponse(infraws.Error(consts.TypeShareStopAck, packet.RequestID, code, err.Error()))
	}

	if c.roomSyncer != nil {
		c.roomSyncer.CloseRoom()
	}
	if c.mirror != nil {
		c.mirror.Clear()
	}
	c.BroadcastShareStatus()
	return conn.WriteResponse(infraws.Success(consts.TypeShareStopAck, packet.RequestID, status))
}

func (c *WSController) handleShareSync(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RoleAdmin {
		return conn.WriteResponse(infraws.Error(consts.TypeShareSyncAck, packet.RequestID, infraws.CodeForbidden, "admin only"))
	}

	var req request.StartShareRequest
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(infraws.Error(consts.TypeShareSyncAck, packet.RequestID, infraws.CodeBadRequest, "invalid request data"))
		}
	}

	status, err := c.share.SyncFiles(req.Files)
	if err != nil {
		code := infraws.CodeBadRequest
		switch {
		case errors.Is(err, share.ErrShareNotActive):
			code = infraws.CodeConflict
		case errors.Is(err, share.ErrNoFiles):
			code = infraws.CodeBadRequest
		}
		return conn.WriteResponse(infraws.Error(consts.TypeShareSyncAck, packet.RequestID, code, err.Error()))
	}

	c.BroadcastShareStatus()
	if c.roomSyncer != nil {
		c.roomSyncer.SyncHostCatalog(status)
	}
	return conn.WriteResponse(infraws.Success(consts.TypeShareSyncAck, packet.RequestID, status))
}

func (c *WSController) handleShareArticleSync(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RoleAdmin {
		return conn.WriteResponse(infraws.Error(consts.TypeShareArticleSyncAck, packet.RequestID, infraws.CodeForbidden, "admin only"))
	}

	var req request.SyncArticleRequest
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(infraws.Error(consts.TypeShareArticleSyncAck, packet.RequestID, infraws.CodeBadRequest, "invalid request data"))
		}
	}

	status, err := c.share.SyncArticles(req.Articles)
	if err != nil {
		code := infraws.CodeBadRequest
		if errors.Is(err, share.ErrShareNotActive) {
			code = infraws.CodeConflict
		}
		return conn.WriteResponse(infraws.Error(consts.TypeShareArticleSyncAck, packet.RequestID, code, err.Error()))
	}

	c.BroadcastShareStatus()
	return conn.WriteResponse(infraws.Success(consts.TypeShareArticleSyncAck, packet.RequestID, status))
}

// BroadcastShareStatus 对外导出：供 bootstrap 在房间目录变更后触发广播。
func (c *WSController) BroadcastShareStatus() {
	if c.ws == nil {
		return
	}
	public := c.buildPublicStatus()
	c.ws.BroadcastToRole(infraws.RoleViewer, infraws.Success(consts.TypeShareStatus, "", public))
}

func (c *WSController) pushShareStatus(conn *infraws.Connection) {
	public := c.buildPublicStatus()
	_ = conn.WriteResponse(infraws.Success(consts.TypeShareStatus, "", public))
}

func (c *WSController) buildPublicStatus() share.PublicStatus {
	status := c.share.Status()
	var catalog []room.SharedEntry
	if c.room != nil {
		catalog, _ = c.room.Catalog()
	}
	var mirror []room.SharedEntry
	if c.mirror != nil && !sharesvc.IsAuthoritativeHost(len(c.room.Members())) {
		mirror = c.mirror.Entries()
	}
	return sharesvc.BuildPublicShareStatus(status, catalog, mirror, resolveLocalBaseURL(c.room, c.share))
}

type publicCatalogSyncRequest struct {
	Catalog []room.SharedEntry `json:"catalog"`
}

func (c *WSController) handlePublicCatalogSync(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RoleAdmin {
		return conn.WriteResponse(infraws.Error(consts.TypePublicCatalogSyncAck, packet.RequestID, infraws.CodeForbidden, "admin only"))
	}

	var req publicCatalogSyncRequest
	if len(packet.Data) > 0 {
		if err := json.Unmarshal(packet.Data, &req); err != nil {
			return conn.WriteResponse(infraws.Error(consts.TypePublicCatalogSyncAck, packet.RequestID, infraws.CodeBadRequest, "invalid request data"))
		}
	}

	if c.mirror != nil {
		c.mirror.Set(req.Catalog)
	}
	c.BroadcastShareStatus()
	return conn.WriteResponse(infraws.Success(consts.TypePublicCatalogSyncAck, packet.RequestID, nil))
}

func (c *WSController) handlePublicCatalogClear(_ context.Context, conn *infraws.Connection, _ []byte, packet infraws.Packet) error {
	if conn.Role() != infraws.RoleAdmin {
		return conn.WriteResponse(infraws.Error(consts.TypePublicCatalogClearAck, packet.RequestID, infraws.CodeForbidden, "admin only"))
	}

	if c.mirror != nil {
		c.mirror.Clear()
	}
	c.BroadcastShareStatus()
	return conn.WriteResponse(infraws.Success(consts.TypePublicCatalogClearAck, packet.RequestID, nil))
}

func resolveLocalBaseURL(room *roomsvc.Service, share *sharesvc.Service) string {
	if room != nil {
		if base := room.HostBaseURL(); base != "" {
			return base
		}
	}
	return share.HTTPBase()
}
