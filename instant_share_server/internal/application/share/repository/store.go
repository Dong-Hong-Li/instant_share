package repository

import "instant_share/server/internal/domain/share"

// Store 本机分享会话持久化端口（当前由 adapter/share/memory 实现）。
type Store interface {
	// Snapshot 返回会话状态副本。
	Snapshot() share.Status
	// ReplaceActive 用给定状态整体替换当前会话（含端口）。
	ReplaceActive(status share.Status)
	// Clear 结束会话并清空文件/文章，保留监听端口。
	Clear()
	// FileByID 按 id 查找本机文件。
	FileByID(id string) (share.ShareFile, bool)
	// Port 当前会话使用的端口。
	Port() int
	// SetPort 更新端口（监听端口回填时使用）。
	SetPort(port int)
}
