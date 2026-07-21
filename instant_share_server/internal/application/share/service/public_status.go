package service

import (
	"fmt"
	"net/url"
	"strings"

	"instant_share/server/internal/domain/room"
	"instant_share/server/internal/domain/share"
	"instant_share/server/internal/util"
)

// BuildPublicShareStatus 组装公开分享状态。
// 优先级：Peer 镜像目录 > 本机房间目录 > 本机分享文件。
// 权威 Host（已有成员）由调用方传入 mirror=nil 强制使用房间目录。
func BuildPublicShareStatus(
	shareStatus share.Status,
	roomCatalog []room.SharedEntry,
	mirror []room.SharedEntry,
	localBaseURL string,
) share.PublicStatus {
	var files []share.PublicShareFile

	switch {
	case len(mirror) > 0:
		files = mapSharedEntriesToPublicFiles(mirror, localBaseURL)
	case len(roomCatalog) > 0:
		files = mapSharedEntriesToPublicFiles(roomCatalog, localBaseURL)
	default:
		files = mapShareFilesToPublicFiles(shareStatus.Files)
	}

	articles := make([]share.PublicShareArticle, 0, len(shareStatus.Articles))
	for _, article := range shareStatus.Articles {
		articles = append(articles, share.PublicShareArticle{
			ID:      article.ID,
			Title:   article.Title,
			Content: article.Content,
		})
	}

	return share.PublicStatus{
		Active:    shareStatus.Active || len(files) > 0,
		SessionID: shareStatus.SessionID,
		Files:     files,
		Articles:  articles,
	}
}

// IsAuthoritativeHost 本机是否为已接纳成员的房间 Host。
func IsAuthoritativeHost(memberCount int) bool {
	return memberCount > 0
}

func mapShareFilesToPublicFiles(files []share.ShareFile) []share.PublicShareFile {
	public := make([]share.PublicShareFile, 0, len(files))
	for _, file := range files {
		public = append(public, share.PublicShareFile{
			ID:          file.ID,
			Name:        file.Name,
			Size:        file.Size,
			SizeText:    util.FormatSize(file.Size),
			DownloadURL: fmt.Sprintf("/api/v1/share/files/%s/download", file.ID),
		})
	}
	return public
}

func mapSharedEntriesToPublicFiles(entries []room.SharedEntry, localBaseURL string) []share.PublicShareFile {
	public := make([]share.PublicShareFile, 0, len(entries))
	for _, entry := range entries {
		public = append(public, share.PublicShareFile{
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

func publicDownloadURL(entry room.SharedEntry, localBaseURL string) string {
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
