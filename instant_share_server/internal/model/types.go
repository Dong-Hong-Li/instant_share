package model

import "time"

// ShareFile 单个分享文件。
type ShareFile struct {
	ID   string `json:"id"`
	Path string `json:"path"`
	Name string `json:"name"`
	Size int64  `json:"size"`
}

// ShareStatus 当前分享状态。
type ShareStatus struct {
	Active    bool        `json:"active"`
	SessionID string      `json:"session_id,omitempty"`
	BaseURL   string      `json:"base_url,omitempty"`
	IP        string      `json:"ip,omitempty"`
	Port      int         `json:"port,omitempty"`
	StartedAt *time.Time  `json:"started_at,omitempty"`
	Files     []ShareFile `json:"files"`
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
	HTTPBase string      `json:"http_base"`
	WSURL    string      `json:"ws_url"`
	ShareURL string      `json:"share_url"`
	Share    ShareStatus `json:"share"`
}
