// Package room 定义互享配对房间的领域模型。
package room

import "time"

// SharedFileMeta 某一设备发布的单个共享文件元数据（不含他机绝对 URL）。
type SharedFileMeta struct {
	// ID 文件标识。
	ID string `json:"id"`
	// Name 展示文件名。
	Name string `json:"name"`
	// Size 字节大小。
	Size int64 `json:"size"`
	// DownloadPath 相对下载路径，如 /api/v1/share/files/{id}/download。
	DownloadPath string `json:"download_path"`
}

// SharedEntry 聚合目录中的一条跨设备条目（含所有者与可直连的 BaseURL）。
type SharedEntry struct {
	// ID 文件标识。
	ID string `json:"id"`
	// Name 展示文件名。
	Name string `json:"name"`
	// Size 字节大小。
	Size int64 `json:"size"`
	// OwnerID 发布者设备 ID。
	OwnerID string `json:"owner_id"`
	// OwnerDisplayName 发布者展示名。
	OwnerDisplayName string `json:"owner_display_name,omitempty"`
	// BaseURL 所有者本机 HTTP 根，如 http://192.168.1.20:8080。
	BaseURL string `json:"base_url"`
	// DownloadPath 相对下载路径。
	DownloadPath string `json:"download_path"`
}

// PendingRequest 等待 Host 审批的配对请求。
type PendingRequest struct {
	// DeviceID 申请方设备 ID。
	DeviceID string `json:"device_id"`
	// DisplayName 申请方展示名。
	DisplayName string `json:"display_name"`
	// PeerBaseURL 申请方本机 HTTP 根，用于后续直连下载。
	PeerBaseURL string `json:"peer_base_url"`
	// RequestedAt 首次申请时间（同设备刷新请求时保留）。
	RequestedAt time.Time `json:"requested_at"`
	// ExpiresAt 过期时间（PairingTTL）。
	ExpiresAt time.Time `json:"expires_at"`
}

// Member 已通过审批的房间成员。
type Member struct {
	// DeviceID 成员设备 ID。
	DeviceID string `json:"device_id"`
	// DisplayName 展示名。
	DisplayName string `json:"display_name"`
	// PeerBaseURL 成员本机 HTTP 根。
	PeerBaseURL string `json:"peer_base_url"`
}
