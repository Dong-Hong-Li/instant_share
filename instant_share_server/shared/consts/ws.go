// Package consts 跨层共享字面量（WebSocket 角色与帧 type，与 Flutter/Web 对齐）。
package consts

// WebSocket 角色与帧类型字面量（与现网 Flutter/Web 对齐，本轮不改字面量）。
const (
	RoleAdmin  = "admin"  // Host 管理端
	RolePeer   = "peer"   // 已配对或待配对 Peer
	RoleViewer = "viewer" // 接收者（只读 share.status）

	TypeShareStart            = "share.start"              // Admin 开启分享
	TypeShareStartAck         = "share.start_ack"          // 开启分享应答
	TypeShareStop             = "share.stop"               // Admin 停止分享
	TypeShareStopAck          = "share.stop_ack"           // 停止分享应答
	TypeShareSync             = "share.sync"               // Admin 同步文件列表
	TypeShareSyncAck          = "share.sync_ack"           // 文件同步应答
	TypeShareArticleSync      = "share.article.sync"       // Admin 同步文章
	TypeShareArticleSyncAck   = "share.article.sync_ack"   // 文章同步应答
	TypeShareStatus           = "share.status"             // 公开分享状态推送（Viewer）
	TypePairingRequest        = "pairing.request"          // Peer 提交配对
	TypePairingRequestAck     = "pairing.request_ack"      // 配对请求应答
	TypePairingDecide         = "pairing.decide"           // Admin 审批/拒绝
	TypePairingDecideAck      = "pairing.decide_ack"       // 审批操作应答
	TypePairingApprove        = "pairing.approve"          // 配对通过通知（→ Peer）
	TypePairingReject         = "pairing.reject"           // 配对拒绝通知（→ Peer）
	TypePairingTimeout        = "pairing.timeout"          // 配对请求过期（→ Peer）
	TypePairingCancel         = "pairing.cancel"           // Peer 主动撤回待审批申请
	TypePairingCancelAck      = "pairing.cancel_ack"       // 撤回申请应答
	TypeShareOffer            = "share.offer"              // Peer 上报文件分片
	TypeShareOfferAck         = "share.offer_ack"          // share.offer 应答
	TypeRoomNotify            = "room.notify"              // 房间事件广播（catalog/pending/closed）
	TypeRoomSnapshot          = "room.snapshot"            // 拉取房间快照
	TypeRoomSnapshotAck       = "room.snapshot_ack"        // 房间快照应答
	TypeRoomLeave             = "room.leave"               // Peer 主动离房
	TypeRoomLeaveAck          = "room.leave_ack"           // 离房应答
	TypePublicCatalogSync     = "room.public_catalog.sync"     // Admin 写入 Peer 公开目录镜像
	TypePublicCatalogSyncAck  = "room.public_catalog.sync_ack" // 镜像同步应答
	TypePublicCatalogClear    = "room.public_catalog.clear"    // Admin 清空公开目录镜像
	TypePublicCatalogClearAck = "room.public_catalog.clear_ack" // 镜像清空应答
)
