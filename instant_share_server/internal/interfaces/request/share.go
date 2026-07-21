package request

import "instant_share/server/internal/domain/share"

// StartShareRequest Flutter 启动分享请求。
type StartShareRequest struct {
	Port  int               `json:"port,omitempty"`
	Files []share.ShareFile `json:"files"`
}

// SyncArticleRequest Admin 同步分享文章列表。
type SyncArticleRequest struct {
	Articles []share.ShareArticle `json:"articles"`
}
