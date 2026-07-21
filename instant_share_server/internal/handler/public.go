package handler

import (
	"fmt"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"strings"

	"instant_share/server/internal/model"
	"instant_share/server/internal/service"
	webassets "instant_share/server/internal/web"
)

// PublicHandler 接收者页面：通过 HTTP 查看当前分享的文件列表。
type PublicHandler struct {
	share  fs.FS
	files  *service.ShareService
	room   *service.RoomService
	mirror *service.PublicRoomCatalog
}

// NewPublicHandler 创建公开访问处理器。
func NewPublicHandler(share *service.ShareService, room *service.RoomService, mirror *service.PublicRoomCatalog) *PublicHandler {
	return &PublicHandler{
		share:  webassets.FS(),
		files:  share,
		room:   room,
		mirror: mirror,
	}
}

// Register 注册路由。
func (h *PublicHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("/", h.handleRoot)
	mux.HandleFunc("/share", h.handleShareEntry)
	mux.Handle("/share/", h.handleShareStatic())
	mux.HandleFunc("/api/v1/share/status", h.handleShareStatus)
	mux.HandleFunc("/api/v1/share/files/batch/download", h.handleBatchDownload)
	mux.HandleFunc("/api/v1/share/files/", h.handleShareFileDownload)
}

// handleRoot 处理首页。
func (h *PublicHandler) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share/", http.StatusFound)
}

// handleShareEntry 处理分享入口。
func (h *PublicHandler) handleShareEntry(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/share" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share/", http.StatusFound)
}

// handleShareStatic 处理静态资源。
func (h *PublicHandler) handleShareStatic() http.Handler {
	fileServer := http.StripPrefix("/share/", webassets.FileServer())

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/share/")
		if path == "" || path == "/" {
			path = "index.html"
		}

		if _, err := fs.Stat(h.share, path); err != nil {
			fallback := r.Clone(r.Context())
			fallback.URL.Path = "/share/index.html"
			fileServer.ServeHTTP(w, fallback)
			return
		}

		fileServer.ServeHTTP(w, r)
	})
}

// handleShareStatus 处理分享状态。
func (h *PublicHandler) handleShareStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}

	status := h.files.Status()
	var catalog []model.SharedEntry
	if h.room != nil {
		catalog, _ = h.room.Catalog()
	}
	var mirror []model.SharedEntry
	if h.mirror != nil && !isRoomHost(h.room) {
		mirror = h.mirror.Entries()
	}
	data := buildPublicShareStatus(status, catalog, mirror, resolveLocalBaseURL(h.room, h.files))
	writeJSON(w, http.StatusOK, model.APIResponse{
		OK:   true,
		Data: data,
	})
}

// resolveLocalBaseURL 计算「本机」的公开基础地址：
// Host 且房间已开启时优先使用 RoomService.HostBaseURL；
// 否则（Peer 镜像场景或房间未开启）回退到 ShareService 的本机 HTTP 基础地址，
// 以便镜像中属于本机的条目仍能命中相对下载路径。
func resolveLocalBaseURL(room *service.RoomService, share *service.ShareService) string {
	if room != nil {
		if base := room.HostBaseURL(); base != "" {
			return base
		}
	}
	return share.HTTPBase()
}

// isRoomHost 判断本机是否为某个互传房间「权威 Host」——即已有至少一个通过配对审批的成员
// （room.Members() 非空）。仅凭 HostBaseURL != "" 不足以判定 Host：Peer 自己开始本地分享时
// 也会把 SyncHostCatalog 写入的临时 HostBaseURL 留下，若据此判定为 Host 会错误地忽略本节点
// 作为 Peer 聚合到的镜像目录。只有真正接纳了成员的房间主机才应以 RoomService.Catalog 为准、
// 忽略 Peer 镜像。
func isRoomHost(room *service.RoomService) bool {
	return room != nil && len(room.Members()) > 0
}

// handleShareFileDownload 处理文件下载。
func (h *PublicHandler) handleShareFileDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}

	status := h.files.Status()
	if !status.Active {
		writeError(w, http.StatusNotFound, "share is not active")
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/api/v1/share/files/")
	id := strings.TrimSuffix(path, "/download")
	id = strings.Trim(id, "/")
	if id == "" || strings.Contains(id, "/") || strings.HasPrefix(id, "batch") {
		http.NotFound(w, r)
		return
	}

	file, ok := h.files.FileByID(id)
	if !ok {
		http.NotFound(w, r)
		return
	}

	f, err := os.Open(file.Path)
	if err != nil {
		writeError(w, http.StatusNotFound, "file not found")
		return
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "file not readable")
		return
	}
	if info.IsDir() {
		writeError(w, http.StatusBadRequest, "directory download is not supported")
		return
	}

	w.Header().Set("Content-Disposition", contentDispositionAttachment(file.Name))
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeContent(w, r, file.Name, info.ModTime(), f)
}

// contentDispositionAttachment 生成下载响应头。
func contentDispositionAttachment(filename string) string {
	ascii := strings.Map(func(r rune) rune {
		if r > 127 || r == '"' || r == '\\' {
			return '_'
		}
		return r
	}, filename)
	return fmt.Sprintf(`attachment; filename="%s"; filename*=UTF-8''%s`, ascii, url.PathEscape(filename))
}
