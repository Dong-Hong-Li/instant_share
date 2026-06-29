package handler

import (
	"fmt"

	"instant_share/server/internal/model"
	"instant_share/server/internal/util"
)

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

	return model.PublicShareStatus{
		Active:    status.Active,
		SessionID: status.SessionID,
		Files:     files,
		Article:   toPublicShareArticle(status.Article),
	}
}

func toPublicShareArticle(article *model.ShareArticle) *model.PublicShareArticle {
	if article == nil {
		return nil
	}
	return &model.PublicShareArticle{
		ID:      article.ID,
		Title:   article.Title,
		Content: article.Content,
	}
}
