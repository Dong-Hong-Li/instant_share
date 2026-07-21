package memory

import (
	"sync"

	"instant_share/server/internal/domain/share"
)

// Store 内存分享会话存储。
type Store struct {
	mu     sync.RWMutex
	port   int
	status share.Status
}

// NewStore 创建内存 Store。
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

// Snapshot 返回状态副本。
func (s *Store) Snapshot() share.Status {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return share.CloneStatus(s.status)
}

// ReplaceActive 替换为活跃会话状态。
func (s *Store) ReplaceActive(status share.Status) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.status = share.CloneStatus(status)
	s.port = status.Port
}

// Clear 清空会话，保留端口。
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

// FileByID 按 id 查找文件。
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

// Port 返回当前端口。
func (s *Store) Port() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.port
}

// SetPort 更新端口。
func (s *Store) SetPort(port int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.port = port
	s.status.Port = port
}
