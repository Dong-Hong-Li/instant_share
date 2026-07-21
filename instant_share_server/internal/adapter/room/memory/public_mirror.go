// Package memory 实现 room 上下文的内存侧 repository 端口。
package memory

import (
	"sync"

	"instant_share/server/internal/domain/room"
)

// PublicMirror 实现 application/room/repository.PublicMirror（进程内内存）。
type PublicMirror struct {
	mu      sync.RWMutex
	entries []room.SharedEntry
}

/**
 * @description: NewPublicMirror 创建空镜像。
 * @return {*PublicMirror}
 */
func NewPublicMirror() *PublicMirror {
	return &PublicMirror{entries: nil}
}

/**
 * @description: Set 覆盖镜像条目；nil 表示清空。
 * @param {[]room.SharedEntry} entries
 */
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

/**
 * @description: Clear 清空镜像。
 */
func (s *PublicMirror) Clear() {
	s.Set(nil)
}

/**
 * @description: Entries 返回镜像副本；无数据时返回 nil。
 * @return {[]room.SharedEntry}
 */
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
