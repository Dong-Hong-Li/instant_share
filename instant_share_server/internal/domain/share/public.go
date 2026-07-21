package share

// PublicShareArticle 面向接收者（Web /share）的文章视图。
type PublicShareArticle struct {
	// ID 文章标识。
	ID string `json:"id"`
	// Title 标题。
	Title string `json:"title"`
	// Content 正文。
	Content string `json:"content"`
}

// PublicShareFile 面向接收者的文件视图（不含本地 Path）。
type PublicShareFile struct {
	// ID 文件标识，用于本机下载路径拼接。
	ID string `json:"id"`
	// Name 展示文件名。
	Name string `json:"name"`
	// Size 字节大小。
	Size int64 `json:"size"`
	// SizeText 人类可读大小（如 1.2 MB）。
	SizeText string `json:"size_text"`
	// DownloadURL 相对路径（本机）或绝对 URL（他机直连所有者）。
	DownloadURL string `json:"download_url"`
	// OwnerDisplayName 跨设备目录中的所有者展示名。
	OwnerDisplayName string `json:"owner_display_name,omitempty"`
}

// PublicStatus 面向接收者的公开分享状态（HTTP status / WS share.status）。
type PublicStatus struct {
	// Active 是否有可展示内容：本机分享中，或目录非空。
	Active bool `json:"active"`
	// SessionID 本机分享会话 ID（若有）。
	SessionID string `json:"session_id,omitempty"`
	// Files 文件列表（来源见 BuildPublicShareStatus 优先级）。
	Files []PublicShareFile `json:"files"`
	// Articles 始终来自本机分享状态，不做多机聚合。
	Articles []PublicShareArticle `json:"articles"`
}
