package service

import (
	"fmt"
	"time"

	"instant_share/server/internal/application/share/repository"
	"instant_share/server/internal/domain/share"
	"instant_share/server/internal/util"

	"github.com/google/uuid"
)

// Service 本机分享用例。
type Service struct {
	store repository.Store
	host  string
}

// NewService 创建分享用例服务。初始端口由 store 持有，port 参数保留以兼容装配签名。
func NewService(store repository.Store, host string, port int) *Service {
	_ = port
	return &Service{store: store, host: host}
}

// Status 返回当前分享状态副本。
func (s *Service) Status() share.Status {
	return s.store.Snapshot()
}

// HTTPBase 返回本机对外可访问的 HTTP 基础地址（不含 /share 后缀）。
func (s *Service) HTTPBase() string {
	return fmt.Sprintf("http://%s:%d", util.PrimaryLocalIP(), s.store.Port())
}

// Start 开启分享会话。overridePort>0 时覆盖监听端口字段。
func (s *Service) Start(files []share.ShareFile, overridePort int) (share.Status, error) {
	current := s.store.Snapshot()
	if current.Active {
		return current, share.ErrShareActive
	}

	normalized, err := share.NormalizeFiles(files)
	if err != nil {
		return current, err
	}

	port := s.store.Port()
	if overridePort > 0 {
		port = overridePort
	}

	ip := util.PrimaryLocalIP()
	startedAt := time.Now()
	status := share.Status{
		Active:    true,
		SessionID: uuid.NewString(),
		IP:        ip,
		Port:      port,
		BaseURL:   fmt.Sprintf("http://%s:%d/share", ip, port),
		StartedAt: &startedAt,
		Files:     normalized,
		Articles:  []share.ShareArticle{},
	}
	s.store.ReplaceActive(status)
	return s.store.Snapshot(), nil
}

// SyncFiles 分享进行中同步文件列表。
func (s *Service) SyncFiles(files []share.ShareFile) (share.Status, error) {
	current := s.store.Snapshot()
	if !current.Active {
		return current, share.ErrShareNotActive
	}
	normalized, err := share.NormalizeFiles(files)
	if err != nil {
		return current, err
	}
	current.Files = normalized
	s.store.ReplaceActive(current)
	return s.store.Snapshot(), nil
}

// SyncArticles 分享进行中同步文章列表。
func (s *Service) SyncArticles(articles []share.ShareArticle) (share.Status, error) {
	current := s.store.Snapshot()
	if !current.Active {
		return current, share.ErrShareNotActive
	}
	normalized, err := share.NormalizeArticles(articles)
	if err != nil {
		return current, err
	}
	current.Articles = normalized
	s.store.ReplaceActive(current)
	return s.store.Snapshot(), nil
}

// Stop 停止分享会话。
func (s *Service) Stop() (share.Status, error) {
	current := s.store.Snapshot()
	if !current.Active {
		return current, share.ErrShareNotActive
	}
	s.store.Clear()
	return s.store.Snapshot(), nil
}

// FileByID 根据 ID 查找分享文件。
func (s *Service) FileByID(id string) (share.ShareFile, bool) {
	return s.store.FileByID(id)
}
