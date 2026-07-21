package repository

import "instant_share/server/internal/domain/room"

// PublicMirror Peer 侧公开房间目录镜像端口。
//
// Flutter Peer 收到 Host 聚合 catalog 后，经 room.public_catalog.sync 写入本机镜像，
// 使本机 /share 也能展示跨设备文件；权威 Host（Members 非空）组装公开状态时忽略镜像。
type PublicMirror interface {
	// Set 覆盖镜像目录（nil 表示清空）。
	Set(entries []room.SharedEntry)
	// Clear 清空镜像。
	Clear()
	// Entries 返回镜像副本；空时返回 nil。
	Entries() []room.SharedEntry
}

// CatalogUpdatedHook 房间聚合目录变更后的回调（由 bootstrap 注入，用于广播）。
type CatalogUpdatedHook func()

// PendingUpdatedHook 待审批列表变更后的回调。
type PendingUpdatedHook func()
