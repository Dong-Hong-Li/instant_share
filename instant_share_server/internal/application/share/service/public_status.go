package service

import (
	"fmt"
	"net/url"
	"strings"

	"instant_share/server/internal/domain/room"
	"instant_share/server/internal/domain/share"
	"instant_share/server/internal/util"
)

/**
 * @description: BuildPublicShareStatus 组装面向接收者的公开分享状态。
 * 文件列表优先级：
 *  1. Peer 镜像目录（mirror 非空）—— Peer 聚合到的跨设备完整目录；
 *  2. 本机房间聚合目录（roomCatalog 非空）；
 *  3. 本机分享文件（shareStatus.Files）。
 * 权威 Host（已有成员）必须由调用方传 mirror=nil，强制走房间目录，避免残留镜像抢占。
 * articles 始终取自本机 shareStatus，不做多机聚合。
 * active = shareStatus.Active || len(files) > 0。
 * @param {share.Status} shareStatus 本机分享快照
 * @param {[]room.SharedEntry} roomCatalog 本机 RoomService 聚合目录
 * @param {[]room.SharedEntry} mirror Peer 镜像目录；权威 Host 应传 nil
 * @param {string} localBaseURL 判定「本机条目」用的 HTTP 根（相对 vs 绝对 download_url）
 * @return {share.PublicStatus}
 */
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

/**
 * @description: IsAuthoritativeHost 判定本机是否为「权威 Host」——已有至少一个审批通过的成员。
 * 仅 HostBaseURL != "" 不够：Peer 本地分享也可能留下临时 HostBaseURL。
 * @param {int} memberCount room.Members() 长度
 * @return {bool}
 */
func IsAuthoritativeHost(memberCount int) bool {
	return memberCount > 0
}

// mapShareFilesToPublicFiles 本机分享文件 → 相对 download_url。
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

// mapSharedEntriesToPublicFiles 房间/镜像条目 → 公开文件；本机相对路径，他机绝对 URL。
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

// publicDownloadURL 本机条目用相对路径，跨设备条目拼所有者绝对地址（浏览器直连，不中转）。
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
