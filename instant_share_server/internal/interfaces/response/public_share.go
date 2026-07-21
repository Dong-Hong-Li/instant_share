package response

import "instant_share/server/internal/domain/share"

// 对外 DTO 与 domain 公开读模型字段一致，便于 JSON 序列化复用。

// PublicShareStatus 公开分享状态响应。
type PublicShareStatus = share.PublicStatus

// PublicShareFile 公开文件条目。
type PublicShareFile = share.PublicShareFile

// PublicShareArticle 公开文章。
type PublicShareArticle = share.PublicShareArticle
