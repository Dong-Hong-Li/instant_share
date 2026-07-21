package request

import "instant_share/server/internal/domain/share"

// ServerHealth admin 客户端启动前探测响应 data 结构。
type ServerHealth struct {
	Service  string       `json:"service"`    // 服务名
	Healthy  bool         `json:"healthy"`    // 是否可用
	Port     int          `json:"port"`       // 实际监听端口
	LANIP    string       `json:"lan_ip"`     // 首选局域网 IP
	LocalIPs []string     `json:"local_ips"`  // 本机全部 IP
	HTTPBase string       `json:"http_base"`  // 本机 HTTP 根
	WSURL    string       `json:"ws_url"`     // WebSocket 地址
	ShareURL string       `json:"share_url"`  // 接收者页面 URL（LAN）
	Share    share.Status `json:"share"`      // 当前分享快照
}
