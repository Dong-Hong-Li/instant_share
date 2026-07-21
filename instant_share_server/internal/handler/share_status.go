package handler

import (
	"fmt"
	"net/url"
	"strings"

	"instant_share/server/internal/model"
	"instant_share/server/internal/util"
)

func buildPublicShareStatus(
	share model.ShareStatus,
	roomCatalog []model.SharedEntry,
	mirror []model.SharedEntry,
	localBaseURL string,
) model.PublicShareStatus {
	var files []model.PublicShareFile

	switch {
	case len(roomCatalog) > 0:
		files = mapSharedEntriesToPublicFiles(roomCatalog, localBaseURL)
	case len(mirror) > 0:
		files = mapSharedEntriesToPublicFiles(mirror, localBaseURL)
	default:
		files = mapShareFilesToPublicFiles(share.Files)
	}

	articles := make([]model.PublicShareArticle, 0, len(share.Articles))
	for _, article := range share.Articles {
		articles = append(articles, model.PublicShareArticle{
			ID:      article.ID,
			Title:   article.Title,
			Content: article.Content,
		})
	}

	return model.PublicShareStatus{
		Active:    share.Active || len(files) > 0,
		SessionID: share.SessionID,
		Files:     files,
		Articles:  articles,
	}
}

func mapShareFilesToPublicFiles(files []model.ShareFile) []model.PublicShareFile {
	public := make([]model.PublicShareFile, 0, len(files))
	for _, file := range files {
		public = append(public, model.PublicShareFile{
			ID:          file.ID,
			Name:        file.Name,
			Size:        file.Size,
			SizeText:    util.FormatSize(file.Size),
			DownloadURL: fmt.Sprintf("/api/v1/share/files/%s/download", file.ID),
		})
	}
	return public
}

func mapSharedEntriesToPublicFiles(entries []model.SharedEntry, localBaseURL string) []model.PublicShareFile {
	public := make([]model.PublicShareFile, 0, len(entries))
	for _, entry := range entries {
		public = append(public, model.PublicShareFile{
			ID:               entry.ID,
			Name:             entry.Name,
			Size:             entry.Size,
			SizeText:         util.FormatSize(entry.Size),
			DownloadURL:      publicDownloadURL(entry, localBaseURL),
			OwnerDisplayName: entry.OwnerDisplayName,
		})
	}
	return public
}

func publicDownloadURL(entry model.SharedEntry, localBaseURL string) string {
	if sameBaseURL(entry.BaseURL, localBaseURL) {
		return fmt.Sprintf("/api/v1/share/files/%s/download", entry.ID)
	}
	return absoluteDownloadURL(entry.BaseURL, entry.DownloadPath)
}

func absoluteDownloadURL(baseURL, downloadPath string) string {
	base, err := url.Parse(baseURL)
	if err != nil {
		return downloadPath
	}
	ref, err := url.Parse(downloadPath)
	if err != nil {
		return downloadPath
	}
	return base.ResolveReference(ref).String()
}

func sameBaseURL(a, b string) bool {
	a = strings.TrimRight(strings.TrimSpace(a), "/")
	b = strings.TrimRight(strings.TrimSpace(b), "/")
	if a == b {
		return true
	}
	ua, errA := url.Parse(a)
	ub, errB := url.Parse(b)
	if errA != nil || errB != nil {
		return a == b
	}
	return ua.Scheme == ub.Scheme && ua.Host == ub.Host
}

// toPublicShareStatus 转换为公开分享状态。
func toPublicShareStatus(status model.ShareStatus) model.PublicShareStatus {
	return buildPublicShareStatus(status, nil, nil, status.BaseURL)
}
