// Package memory 分享会话内存仓储实现。
package memory

import (
	"sync"

	"instant_share/server/internal/domain/share"
)

// Store 内存分享会话存储（进程内单例）。
type Store struct {
	mu     sync.RWMutex
	port   int          // 默认/当前 HTTP 端口
	status share.Status // 当前分享快照
}

// NewStore 创建内存 Store，初始为未分享状态。
func NewStore(port int) *Store {
	return &Store{
		port: port,
		status: share.Status{
			Active:   false,
			Port:     port,
			Files:    []share.ShareFile{},
			Articles: []share.ShareArticle{},
		},
	}
}

// Snapshot 返回状态深拷贝，避免调用方误改内部数据。
func (s *Store) Snapshot() share.Status {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return share.CloneStatus(s.status)
}

// ReplaceActive 整体替换为新的活跃分享会话。
func (s *Store) ReplaceActive(status share.Status) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.status = share.CloneStatus(status)
	s.port = status.Port
}

// Clear 停止分享并清空文件/文章，保留 port 配置。
func (s *Store) Clear() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.status = share.Status{
		Active:   false,
		Port:     s.port,
		Files:    []share.ShareFile{},
		Articles: []share.ShareArticle{},
	}
}

// FileByID 在当前分享文件列表中按 id 查找。
func (s *Store) FileByID(id string) (share.ShareFile, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, file := range s.status.Files {
		if file.ID == id {
			return file, true
		}
	}
	return share.ShareFile{}, false
}

// Port 返回当前端口配置。
func (s *Store) Port() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.port
}

// SetPort 更新端口并同步到 status.Port。
func (s *Store) SetPort(port int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.port = port
	s.status.Port = port
}
