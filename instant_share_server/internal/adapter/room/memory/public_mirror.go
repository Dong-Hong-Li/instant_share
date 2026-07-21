// Package memory 房间相关内存仓储实现。
package memory

import (
	"sync"

	"instant_share/server/internal/domain/room"
)

// PublicMirror 内存公开目录镜像（Peer 聚合目录在 Host 侧的缓存）。
type PublicMirror struct {
	mu      sync.RWMutex
	entries []room.SharedEntry // nil 表示未设置/已清空
}

// NewPublicMirror 创建空镜像 store。
func NewPublicMirror() *PublicMirror {
	return &PublicMirror{entries: nil}
}

// Set 覆盖镜像目录；entries=nil 等价于 Clear。
func (s *PublicMirror) Set(entries []room.SharedEntry) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if entries == nil {
		s.entries = nil
		return
	}
	cp := make([]room.SharedEntry, len(entries))
	copy(cp, entries)
	s.entries = cp
}

// Clear 清空镜像。
func (s *PublicMirror) Clear() {
	s.Set(nil)
}

// Entries 返回镜像副本；无数据时返回 nil（非空切片）。
func (s *PublicMirror) Entries() []room.SharedEntry {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if len(s.entries) == 0 {
		return nil
	}
	cp := make([]room.SharedEntry, len(s.entries))
	copy(cp, s.entries)
	return cp
}
