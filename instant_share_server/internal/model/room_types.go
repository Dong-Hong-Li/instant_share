package model

import "time"

// SharedFileMeta 单个共享文件元数据。
type SharedFileMeta struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Size         int64  `json:"size"`
	DownloadPath string `json:"download_path"`
}

// SharedEntry 跨设备共享目录条目。
type SharedEntry struct {
	ID               string `json:"id"`
	Name             string `json:"name"`
	Size             int64  `json:"size"`
	OwnerID          string `json:"owner_id"`
	OwnerDisplayName string `json:"owner_display_name,omitempty"`
	BaseURL          string `json:"base_url"`
	DownloadPath     string `json:"download_path"`
}

// PendingRequest 待处理配对请求。
type PendingRequest struct {
	DeviceID    string    `json:"device_id"`
	DisplayName string    `json:"display_name"`
	PeerBaseURL string    `json:"peer_base_url"`
	RequestedAt time.Time `json:"requested_at"`
	ExpiresAt   time.Time `json:"expires_at"`
}

// Member 房间成员。
type Member struct {
	DeviceID    string `json:"device_id"`
	DisplayName string `json:"display_name"`
	PeerBaseURL string `json:"peer_base_url"`
}
