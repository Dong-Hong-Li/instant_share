package repository

import "instant_share/server/internal/domain/room"

// PublicMirror Peer 侧公开房间目录镜像端口。
type PublicMirror interface {
	Set(entries []room.SharedEntry)
	Clear()
	Entries() []room.SharedEntry
}

// CatalogUpdatedHook 目录变更回调。
type CatalogUpdatedHook func()

// PendingUpdatedHook 待审批列表变更回调。
type PendingUpdatedHook func()
