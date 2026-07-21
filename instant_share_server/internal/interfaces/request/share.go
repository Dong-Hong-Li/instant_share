// Package request HTTP/WS 入参 DTO（interfaces 层，与 domain 解耦）。
package request

import "instant_share/server/internal/domain/share"

// StartShareRequest Flutter 启动/同步分享文件列表请求。
type StartShareRequest struct {
	Port  int               `json:"port,omitempty"` // 可选自定义 HTTP 端口
	Files []share.ShareFile `json:"files"`          // 本地文件元数据（含 path）
}

// SyncArticleRequest Admin 同步分享文章列表请求。
type SyncArticleRequest struct {
	Articles []share.ShareArticle `json:"articles"`
}
