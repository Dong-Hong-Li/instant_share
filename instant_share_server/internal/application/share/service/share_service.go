package service

import (
	"fmt"
	"time"

	"instant_share/server/internal/application/share/repository"
	"instant_share/server/internal/domain/share"
	"instant_share/server/internal/util"

	"github.com/google/uuid"
)

// Service 本机分享用例：启停会话、同步文件/文章、按 id 查本地文件。
//
// 不负责配对房间与公开目录镜像；公开状态组装见 BuildPublicShareStatus。
type Service struct {
	// store 会话存储端口。
	store repository.Store
	// host 配置中的监听 host（预留；拼 URL 时优先用探测到的局域网 IP）。
	host string
}

/**
 * @description: NewService 创建分享用例服务。
 * @param {repository.Store} store 会话存储（不可为 nil）
 * @param {string} host 配置 host
 * @param {int} port 初始端口由 store 持有；此参数保留以兼容装配签名
 * @return {*Service}
 */
func NewService(store repository.Store, host string, port int) *Service {
	_ = port
	return &Service{store: store, host: host}
}

/**
 * @description: Status 返回当前分享状态副本。
 * @return {share.Status}
 */
func (s *Service) Status() share.Status {
	return s.store.Snapshot()
}

/**
 * @description: HTTPBase 返回本机对外 HTTP 根（不含 /share），与 BaseURL 同源 IP/端口。
 * @return {string} 如 http://192.168.1.10:8080
 */
func (s *Service) HTTPBase() string {
	return fmt.Sprintf("http://%s:%d", util.PrimaryLocalIP(), s.store.Port())
}

/**
 * @description: Start 开启分享会话；已 active 时返回 ErrShareActive。
 * @param {[]share.ShareFile} files 待分享文件（允许空列表）
 * @param {int} overridePort >0 时覆盖会话端口字段
 * @return {share.Status, error}
 */
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

/**
 * @description: SyncFiles 分享进行中替换文件列表。
 * @param {[]share.ShareFile} files
 * @return {share.Status, error} 未 active 时 ErrShareNotActive
 */
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

/**
 * @description: SyncArticles 分享进行中替换文章列表。
 * @param {[]share.ShareArticle} articles
 * @return {share.Status, error}
 */
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

/**
 * @description: Stop 停止分享并清空会话。
 * @return {share.Status, error} 未 active 时 ErrShareNotActive
 */
func (s *Service) Stop() (share.Status, error) {
	current := s.store.Snapshot()
	if !current.Active {
		return current, share.ErrShareNotActive
	}
	s.store.Clear()
	return s.store.Snapshot(), nil
}

/**
 * @description: FileByID 按 id 查找本机分享文件（供下载接口使用）。
 * @param {string} id
 * @return {share.ShareFile, bool}
 */
func (s *Service) FileByID(id string) (share.ShareFile, bool) {
	return s.store.FileByID(id)
}
