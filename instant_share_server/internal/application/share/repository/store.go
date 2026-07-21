package repository

import "instant_share/server/internal/domain/share"

// Store 本机分享会话持久化端口（当前为内存实现）。
type Store interface {
	Snapshot() share.Status
	ReplaceActive(status share.Status)
	Clear()
	FileByID(id string) (share.ShareFile, bool)
	Port() int
	SetPort(port int)
}
