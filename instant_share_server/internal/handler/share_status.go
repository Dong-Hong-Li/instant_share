package handler

import (
	"fmt"

	"instant_share/server/internal/model"
	"instant_share/server/internal/util"
)

// toPublicShareStatus 转换为公开分享状态。
func toPublicShareStatus(status model.ShareStatus) model.PublicShareStatus {
	files := make([]model.PublicShareFile, 0, len(status.Files))
	for _, file := range status.Files {
		files = append(files, model.PublicShareFile{
			ID:          file.ID,
			Name:        file.Name,
			Size:        file.Size,
			SizeText:    util.FormatSize(file.Size),
			DownloadURL: fmt.Sprintf("/api/v1/share/files/%s/download", file.ID),
		})
	}

	articles := make([]model.PublicShareArticle, 0, len(status.Articles))
	for _, article := range status.Articles {
		articles = append(articles, model.PublicShareArticle{
			ID:      article.ID,
			Title:   article.Title,
			Content: article.Content,
		})
	}

	return model.PublicShareStatus{
		Active:    status.Active,
		SessionID: status.SessionID,
		Files:     files,
		Articles:  articles,
	}
}
