package share

// PublicShareArticle 面向接收者浏览的文章内容。
type PublicShareArticle struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	Content string `json:"content"`
}

// PublicShareFile 面向接收者浏览的文件信息（不含本地路径）。
type PublicShareFile struct {
	ID               string `json:"id"`
	Name             string `json:"name"`
	Size             int64  `json:"size"`
	SizeText         string `json:"size_text"`
	DownloadURL      string `json:"download_url"`
	OwnerDisplayName string `json:"owner_display_name,omitempty"`
}

// PublicStatus 面向接收者浏览的分享状态。
type PublicStatus struct {
	Active    bool                 `json:"active"`
	SessionID string               `json:"session_id,omitempty"`
	Files     []PublicShareFile    `json:"files"`
	Articles  []PublicShareArticle `json:"articles"`
}
