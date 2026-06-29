package model

import "time"

// ShareFile 单个分享文件。
type ShareFile struct {
	ID   string `json:"id"`
	Path string `json:"path"`
	Name string `json:"name"`
	Size int64  `json:"size"`
}

// ShareArticle 当前分享的文章（Admin 侧）。
type ShareArticle struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	Content string `json:"content"`
}

// PublicShareArticle 面向接收者浏览的文章内容。
type PublicShareArticle struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	Content string `json:"content"`
}

// ShareStatus 当前分享状态。
type ShareStatus struct {
	Active    bool          `json:"active"`
	SessionID string        `json:"session_id,omitempty"`
	BaseURL   string        `json:"base_url,omitempty"`
	IP        string        `json:"ip,omitempty"`
	Port      int           `json:"port,omitempty"`
	StartedAt *time.Time    `json:"started_at,omitempty"`
	Files     []ShareFile   `json:"files"`
	Article   *ShareArticle `json:"article,omitempty"`
}

// PublicShareFile 面向接收者浏览的文件信息（不含本地路径）。
type PublicShareFile struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Size        int64  `json:"size"`
	SizeText    string `json:"size_text"`
	DownloadURL string `json:"download_url"`
}

// PublicShareStatus 面向接收者浏览的分享状态。
type PublicShareStatus struct {
	Active    bool                `json:"active"`
	SessionID string              `json:"session_id,omitempty"`
	Files     []PublicShareFile   `json:"files"`
	Article   *PublicShareArticle `json:"article,omitempty"`
}

// SyncArticleRequest Admin 同步分享文章。
type SyncArticleRequest struct {
	Article *ShareArticle `json:"article"`
}

// StartShareRequest Flutter 启动分享请求。
type StartShareRequest struct {
	Port  int         `json:"port,omitempty"`
	Files []ShareFile `json:"files"`
}

// APIResponse 通用 JSON 响应。
type APIResponse struct {
	OK      bool   `json:"ok"`
	Message string `json:"message,omitempty"`
	Data    any    `json:"data,omitempty"`
}

// ServerHealth admin 客户端启动前探测：服务是否可用及 WebSocket 地址。
type ServerHealth struct {
	Service  string      `json:"service"`
	Healthy  bool        `json:"healthy"`
	Port     int         `json:"port"`
	LANIP    string      `json:"lan_ip"`
	LocalIPs []string    `json:"local_ips"`
	HTTPBase string      `json:"http_base"`
	WSURL    string      `json:"ws_url"`
	ShareURL string      `json:"share_url"`
	Share    ShareStatus `json:"share"`
}
