// Package share Admin WebSocket 入口：分享启停、文件/文章同步与公开目录镜像。
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

// WSController Admin WebSocket：分享启停与文件列表同步。
type WSController struct {
	share      *sharesvc.Service
	room       *roomsvc.Service
	mirror     *roomsvc.MirrorService
	ws         *infraws.Client
	roomSyncer RoomCatalogSyncer // 分享变更后同步 Host 房间目录 / 关房
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

/**
 * @description: Register 注册 Admin 分享相关 WS 处理器与 Viewer 连接钩子。
 * @param {*infraws.Client} client WebSocket 基础设施客户端
 */
func (c *WSController) Register(client *infraws.Client) {
	client.RegisterHandler(consts.TypeShareStart, c.handleShareStart)
	client.RegisterHandler(consts.TypeShareStop, c.handleShareStop)
	client.RegisterHandler(consts.TypeShareSync, c.handleShareSync)
	client.RegisterHandler(consts.TypeShareArticleSync, c.handleShareArticleSync)
	client.RegisterHandler(consts.TypePublicCatalogSync, c.handlePublicCatalogSync)
	client.RegisterHandler(consts.TypePublicCatalogClear, c.handlePublicCatalogClear)
	client.SetViewerConnectHook(c.handleViewerConnect)
}

// handleViewerConnect Viewer 连上 WS 时立即推送 share.status；无副作用。
func (c *WSController) handleViewerConnect(conn *infraws.Connection) {
	c.pushShareStatus(conn)
}

/**
 * @description: handleShareStart Admin 开启分享。
 * 成功后 SyncHostCatalog 写入 Host 房间目录，再 BroadcastShareStatus 通知 Viewer。
 * @return {error} 写 share.start_ack
 */
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

/**
 * @description: handleShareStop Admin 停止分享。
 * 顺序：share.Stop → CloseRoom（断开 Peer）→ mirror.Clear → BroadcastShareStatus。
 * 权威 Host 关分享时必须清空 Peer 镜像，避免残留目录继续展示。
 * @return {error} 写 share.stop_ack
 */
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

// handleShareSync Admin 替换分享文件列表；广播 share.status 并 SyncHostCatalog；写 share.sync_ack。
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

// handleShareArticleSync Admin 替换分享文章；广播 share.status；写 share.article.sync_ack。
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

/**
 * @description: BroadcastShareStatus 向所有 Viewer 广播 share.status。
 * 由 bootstrap 在房间目录变更后也会调用；不含 room.notify。
 * @return {void}
 */
func (c *WSController) BroadcastShareStatus() {
	if c.ws == nil {
		return
	}
	public := c.buildPublicStatus()
	c.ws.BroadcastToRole(infraws.RoleViewer, infraws.Success(consts.TypeShareStatus, "", public))
}

// pushShareStatus 单连接推送 share.status；Viewer 连接钩子调用。
func (c *WSController) pushShareStatus(conn *infraws.Connection) {
	public := c.buildPublicStatus()
	_ = conn.WriteResponse(infraws.Success(consts.TypeShareStatus, "", public))
}

/**
 * @description: buildPublicStatus 组装 Viewer/HTTP 共用的公开分享状态。
 * 权威 Host（已有成员）忽略 mirror，强制走 room.Catalog；否则可用 Peer 镜像目录。
 * @return {share.PublicStatus}
 */
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

// publicCatalogSyncRequest Peer 聚合完整目录同步到 Host 镜像的请求体。
type publicCatalogSyncRequest struct {
	Catalog []room.SharedEntry `json:"catalog"`
}

// handlePublicCatalogSync Admin 写入 Peer 公开目录镜像并广播 share.status；写 room.public_catalog.sync_ack。
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

// handlePublicCatalogClear Admin 清空 Peer 公开目录镜像并广播 share.status；写 room.public_catalog.clear_ack。
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

// resolveLocalBaseURL 优先 room.HostBaseURL，否则 share.HTTPBase；用于判定本机条目相对路径。
func resolveLocalBaseURL(room *roomsvc.Service, share *sharesvc.Service) string {
	if room != nil {
		if base := room.HostBaseURL(); base != "" {
			return base
		}
	}
	return share.HTTPBase()
}
