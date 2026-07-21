package request

import "instant_share/server/internal/domain/share"

// ServerHealth admin 客户端启动前探测：服务是否可用及 WebSocket 地址。
type ServerHealth struct {
	Service  string       `json:"service"`
	Healthy  bool         `json:"healthy"`
	Port     int          `json:"port"`
	LANIP    string       `json:"lan_ip"`
	LocalIPs []string     `json:"local_ips"`
	HTTPBase string       `json:"http_base"`
	WSURL    string       `json:"ws_url"`
	ShareURL string       `json:"share_url"`
	Share    share.Status `json:"share"`
}
