// Package response HTTP 出参 DTO；公开读模型与 domain 字段一致，便于 JSON 复用。
package response

import "instant_share/server/internal/domain/share"

// PublicShareStatus 公开分享状态响应（alias domain.PublicStatus）。
type PublicShareStatus = share.PublicStatus

// PublicShareFile 公开文件条目（alias domain.PublicShareFile）。
type PublicShareFile = share.PublicShareFile

// PublicShareArticle 公开文章（alias domain.PublicShareArticle）。
type PublicShareArticle = share.PublicShareArticle
