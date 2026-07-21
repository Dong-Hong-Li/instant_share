package service

import (
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"instant_share/server/internal/model"
	"instant_share/server/internal/util"

	"github.com/google/uuid"
)

// maxArticleContentLength。
const maxArticleContentLength = 2000

var (
	// ErrShareNotActive。
	ErrShareNotActive = errors.New("share is not active")
	// ErrShareActive。
	ErrShareActive = errors.New("share is already active")
	// ErrNoFiles。
	ErrNoFiles = errors.New("no files to share")
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
			Active:   false,
			Port:     port,
			Files:    []model.ShareFile{},
			Articles: []model.ShareArticle{},
		},
	}
}

// Status 返回当前分享状态副本。
func (s *ShareService) Status() model.ShareStatus {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return cloneStatus(s.status)
}

// HTTPBase 返回本机对外可访问的 HTTP 基础地址（不含 /share 后缀），
// 与 Start() 中拼接 BaseURL 使用的同一 IP/端口来源保持一致。
func (s *ShareService) HTTPBase() string {
	s.mu.RLock()
	port := s.port
	s.mu.RUnlock()
	return fmt.Sprintf("http://%s:%d", util.PrimaryLocalIP(), port)
}

// Start 开启分享会话。
func (s *ShareService) Start(req model.StartShareRequest) (model.ShareStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.status.Active {
		return s.status, ErrShareActive
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
		Articles:  []model.ShareArticle{},
	}
	s.port = port

	return cloneStatus(s.status), nil
}

// SyncFiles 分享进行中同步文件列表（增删文件）。
func (s *ShareService) SyncFiles(files []model.ShareFile) (model.ShareStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if !s.status.Active {
		return s.status, ErrShareNotActive
	}

	normalized, err := normalizeFiles(files)
	if err != nil {
		return s.status, err
	}

	s.status.Files = normalized
	return cloneStatus(s.status), nil
}

// SyncArticles 分享进行中同步文章列表（增删文章）。
func (s *ShareService) SyncArticles(articles []model.ShareArticle) (model.ShareStatus, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if !s.status.Active {
		return s.status, ErrShareNotActive
	}

	normalized, err := normalizeArticles(articles)
	if err != nil {
		return s.status, err
	}

	s.status.Articles = normalized
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

// resetLocked。
func (s *ShareService) resetLocked() {
	s.status = model.ShareStatus{
		Active:   false,
		Port:     s.port,
		Files:    []model.ShareFile{},
		Articles: []model.ShareArticle{},
	}
}

// normalizeFiles。
func normalizeFiles(files []model.ShareFile) ([]model.ShareFile, error) {
	if len(files) == 0 {
		return []model.ShareFile{}, nil
	}
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

// normalizeArticles。
func normalizeArticles(articles []model.ShareArticle) ([]model.ShareArticle, error) {
	if len(articles) == 0 {
		return []model.ShareArticle{}, nil
	}

	result := make([]model.ShareArticle, 0, len(articles))
	for _, article := range articles {
		content := strings.TrimSpace(article.Content)
		if content == "" {
			return nil, fmt.Errorf("article content is required")
		}
		if utf8.RuneCountInString(content) > maxArticleContentLength {
			return nil, fmt.Errorf("article content exceeds %d characters", maxArticleContentLength)
		}

		id := strings.TrimSpace(article.ID)
		if id == "" {
			id = uuid.NewString()
		}

		result = append(result, model.ShareArticle{
			ID:      id,
			Title:   strings.TrimSpace(article.Title),
			Content: content,
		})
	}
	return result, nil
}

// cloneStatus。
func cloneStatus(status model.ShareStatus) model.ShareStatus {
	files := make([]model.ShareFile, len(status.Files))
	copy(files, status.Files)
	status.Files = files

	articles := make([]model.ShareArticle, len(status.Articles))
	copy(articles, status.Articles)
	status.Articles = articles

	return status
}
