package service

import (
	"errors"
	"fmt"
	"os"
	"sync"
	"time"

	"instant_share/server/internal/model"
	"instant_share/server/internal/util"

	"github.com/google/uuid"
)

var (
	ErrShareNotActive = errors.New("share is not active")
	ErrShareActive    = errors.New("share is already active")
	ErrNoFiles        = errors.New("no files to share")
)

// ShareService 管理分享会话状态。
type ShareService struct {
	mu sync.RWMutex

	host string
	port int

	status model.ShareStatus
}

// NewShareService 创建分享服务。
func NewShareService(host string, port int) *ShareService {
	return &ShareService{
		host: host,
		port: port,
		status: model.ShareStatus{
			Active: false,
			Port:   port,
			Files:  []model.ShareFile{},
		},
	}
}

// Status 返回当前分享状态副本。
func (s *ShareService) Status() model.ShareStatus {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return cloneStatus(s.status)
}

// Start 开启分享会话。
func (s *ShareService) Start(req model.StartShareRequest) (model.ShareStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.status.Active {
		return s.status, ErrShareActive
	}
	if len(req.Files) == 0 {
		return s.status, ErrNoFiles
	}

	files, err := normalizeFiles(req.Files)
	if err != nil {
		return s.status, err
	}

	port := s.port
	if req.Port > 0 {
		port = req.Port
	}

	ip := util.PrimaryLocalIP()
	startedAt := time.Now()

	s.status = model.ShareStatus{
		Active:    true,
		SessionID: uuid.NewString(),
		IP:        ip,
		Port:      port,
		BaseURL:   fmt.Sprintf("http://%s:%d/share", ip, port),
		StartedAt: &startedAt,
		Files:     files,
	}
	s.port = port

	return cloneStatus(s.status), nil
}

// Stop 停止分享会话。
func (s *ShareService) Stop() (model.ShareStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if !s.status.Active {
		return s.status, ErrShareNotActive
	}

	s.resetLocked()
	return cloneStatus(s.status), nil
}

// FileByID 根据 ID 查找分享文件。
func (s *ShareService) FileByID(id string) (model.ShareFile, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, file := range s.status.Files {
		if file.ID == id {
			return file, true
		}
	}
	return model.ShareFile{}, false
}

func (s *ShareService) resetLocked() {
	s.status = model.ShareStatus{
		Active: false,
		Port:   s.port,
		Files:  []model.ShareFile{},
	}
}

func normalizeFiles(files []model.ShareFile) ([]model.ShareFile, error) {
	result := make([]model.ShareFile, 0, len(files))
	for _, file := range files {
		if file.Path == "" {
			return nil, fmt.Errorf("file path is required")
		}
		info, err := os.Stat(file.Path)
		if err != nil {
			return nil, fmt.Errorf("invalid file %q: %w", file.Path, err)
		}
		if info.IsDir() {
			return nil, fmt.Errorf("directory sharing is not supported yet: %q", file.Path)
		}

		name := file.Name
		if name == "" {
			name = info.Name()
		}
		id := file.ID
		if id == "" {
			id = uuid.NewString()
		}

		result = append(result, model.ShareFile{
			ID:   id,
			Path: file.Path,
			Name: name,
			Size: info.Size(),
		})
	}
	return result, nil
}

func cloneStatus(status model.ShareStatus) model.ShareStatus {
	files := make([]model.ShareFile, len(status.Files))
	copy(files, status.Files)
	status.Files = files
	return status
}
