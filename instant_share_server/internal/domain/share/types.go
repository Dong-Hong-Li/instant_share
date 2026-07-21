// Package share 定义本机分享会话的领域模型（无 I/O、无 HTTP/WS 依赖）。
package share

import "time"

// ShareFile 单个待分享 / 已分享的本地文件。
type ShareFile struct {
	// ID 文件标识；空则在 Normalize 时生成 UUID。
	ID string `json:"id"`
	// Path 本机绝对路径（仅 admin/服务端使用，不对外公开）。
	Path string `json:"path"`
	// Name 展示用文件名。
	Name string `json:"name"`
	// Size 字节大小（Normalize 时按磁盘文件回填）。
	Size int64 `json:"size"`
}

// ShareArticle 当前分享中的文章（Admin 侧原文）。
type ShareArticle struct {
	// ID 文章标识。
	ID string `json:"id"`
	// Title 标题（可空）。
	Title string `json:"title"`
	// Content 正文（必填，有最大长度限制）。
	Content string `json:"content"`
}

// Status 本机分享会话快照。
type Status struct {
	// Active 是否正在分享。
	Active bool `json:"active"`
	// SessionID 本次分享会话 ID。
	SessionID string `json:"session_id,omitempty"`
	// BaseURL 对外分享页地址，形如 http://ip:port/share。
	BaseURL string `json:"base_url,omitempty"`
	// IP 用于拼接 BaseURL 的局域网 IP。
	IP string `json:"ip,omitempty"`
	// Port HTTP 监听端口。
	Port int `json:"port,omitempty"`
	// StartedAt 开启时间。
	StartedAt *time.Time `json:"started_at,omitempty"`
	// Files 本机文件列表。
	Files []ShareFile `json:"files"`
	// Articles 本机文章列表（不做多机聚合）。
	Articles []ShareArticle `json:"articles"`
}
