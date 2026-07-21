package share

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

// Status 当前分享状态。
type Status struct {
	Active    bool           `json:"active"`
	SessionID string         `json:"session_id,omitempty"`
	BaseURL   string         `json:"base_url,omitempty"`
	IP        string         `json:"ip,omitempty"`
	Port      int            `json:"port,omitempty"`
	StartedAt *time.Time     `json:"started_at,omitempty"`
	Files     []ShareFile    `json:"files"`
	Articles  []ShareArticle `json:"articles"`
}
