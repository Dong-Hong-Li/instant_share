// Package memory 实现 share 上下文的内存侧 repository 端口。
package memory

import (
	"sync"

	"instant_share/server/internal/domain/share"
)

// Store 实现 application/share/repository.Store（进程内内存）。
type Store struct {
	mu     sync.RWMutex
	port   int
	status share.Status
}

/**
 * @description: NewStore 创建空闲会话存储。
 * @param {int} port 初始 HTTP 端口
 * @return {*Store}
 */
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

/**
 * @description: Snapshot 返回状态深拷贝。
 * @return {share.Status}
 */
func (s *Store) Snapshot() share.Status {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return share.CloneStatus(s.status)
}

/**
 * @description: ReplaceActive 整体替换会话状态，并同步 port 字段。
 * @param {share.Status} status
 */
func (s *Store) ReplaceActive(status share.Status) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.status = share.CloneStatus(status)
	s.port = status.Port
}

/**
 * @description: Clear 清空会话内容，保留 port。
 */
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

/**
 * @description: FileByID 按 id 查找文件。
 * @param {string} id
 * @return {share.ShareFile, bool}
 */
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

/**
 * @description: Port 读取当前端口。
 * @return {int}
 */
func (s *Store) Port() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.port
}

/**
 * @description: SetPort 更新端口与状态中的 Port 字段。
 * @param {int} port
 */
func (s *Store) SetPort(port int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.port = port
	s.status.Port = port
}
