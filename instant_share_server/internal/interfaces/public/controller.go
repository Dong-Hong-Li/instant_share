// Package public 接收者 HTTP 入口：分享页静态资源、公开状态与文件下载。
package public

import (
	"fmt"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"strings"

	roomsvc "instant_share/server/internal/application/room/service"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/internal/domain/room"
	"instant_share/server/internal/domain/share"
	"instant_share/server/internal/delivery/res"
	webassets "instant_share/server/internal/web"
)

// Controller 接收者页面：通过 HTTP 查看当前分享的文件列表。
type Controller struct {
	share  fs.FS                 // 嵌入的 Web 静态资源
	files  *sharesvc.Service     // 本机分享会话
	room   *roomsvc.Service      // 房间聚合目录
	mirror *roomsvc.MirrorService // Peer 公开目录镜像
}

// NewController 创建公开访问控制器。
func NewController(files *sharesvc.Service, room *roomsvc.Service, mirror *roomsvc.MirrorService) *Controller {
	return &Controller{
		share:  webassets.FS(),
		files:  files,
		room:   room,
		mirror: mirror,
	}
}

// Register 注册公开 HTTP 路由（根路径重定向、静态页、状态与下载）。
func (c *Controller) Register(mux *http.ServeMux) {
	mux.HandleFunc("/", c.handleRoot)
	mux.HandleFunc("/share", c.handleShareEntry)
	mux.Handle("/share/", c.handleShareStatic())
	mux.HandleFunc("/api/v1/share/status", c.handleShareStatus)
	mux.HandleFunc("/api/v1/share/files/batch/download", c.handleBatchDownload)
	mux.HandleFunc("/api/v1/share/files/", c.handleShareFileDownload)
}

// handleRoot GET / 重定向到 /share/；其他路径 404。
func (c *Controller) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share/", http.StatusFound)
}

// handleShareEntry GET /share 重定向到 /share/。
func (c *Controller) handleShareEntry(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/share" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share/", http.StatusFound)
}

// handleShareStatic 分享页 SPA 静态资源；未知路径回退 index.html。
func (c *Controller) handleShareStatic() http.Handler {
	fileServer := http.StripPrefix("/share/", webassets.FileServer())

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/share/")
		if path == "" || path == "/" {
			path = "index.html"
		}

		if _, err := fs.Stat(c.share, path); err != nil {
			fallback := r.Clone(r.Context())
			fallback.URL.Path = "/share/index.html"
			fileServer.ServeHTTP(w, fallback)
			return
		}

		fileServer.ServeHTTP(w, r)
	})
}

// handleShareStatus GET 返回与 WS share.status 同构的公开状态 JSON。
func (c *Controller) handleShareStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		res.MethodNotAllowed(w)
		return
	}

	data := c.buildPublicStatus()
	res.WriteJSON(w, http.StatusOK, res.APIResponse{
		OK:   true,
		Data: data,
	})
}

/**
 * @description: buildPublicStatus 组装 HTTP 公开分享状态（逻辑与 share WS 控制器一致）。
 * 权威 Host 忽略 mirror，优先 room.Catalog。
 * @return {share.PublicStatus}
 */
func (c *Controller) buildPublicStatus() share.PublicStatus {
	status := c.files.Status()
	var catalog []room.SharedEntry
	if c.room != nil {
		catalog, _ = c.room.Catalog()
	}
	var mirror []room.SharedEntry
	if c.mirror != nil && !sharesvc.IsAuthoritativeHost(len(c.room.Members())) {
		mirror = c.mirror.Entries()
	}
	return sharesvc.BuildPublicShareStatus(status, catalog, mirror, resolveLocalBaseURL(c.room, c.files))
}

// resolveLocalBaseURL 优先 room.HostBaseURL，否则 share.HTTPBase。
func resolveLocalBaseURL(room *roomsvc.Service, share *sharesvc.Service) string {
	if room != nil {
		if base := room.HostBaseURL(); base != "" {
			return base
		}
	}
	return share.HTTPBase()
}

// handleShareFileDownload GET 单文件下载；分享未 active 或 id 无效时 404。
func (c *Controller) handleShareFileDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		res.MethodNotAllowed(w)
		return
	}

	status := c.files.Status()
	if !status.Active {
		res.WriteError(w, http.StatusNotFound, "share is not active")
		return
	}

	path := strings.TrimPrefix(r.URL.Path, "/api/v1/share/files/")
	id := strings.TrimSuffix(path, "/download")
	id = strings.Trim(id, "/")
	if id == "" || strings.Contains(id, "/") || strings.HasPrefix(id, "batch") {
		http.NotFound(w, r)
		return
	}

	file, ok := c.files.FileByID(id)
	if !ok {
		http.NotFound(w, r)
		return
	}

	f, err := os.Open(file.Path)
	if err != nil {
		res.WriteError(w, http.StatusNotFound, "file not found")
		return
	}
	defer f.Close()

	info, err := f.Stat()
	if err != nil {
		res.WriteError(w, http.StatusInternalServerError, "file not readable")
		return
	}
	if info.IsDir() {
		res.WriteError(w, http.StatusBadRequest, "directory download is not supported")
		return
	}

	w.Header().Set("Content-Disposition", contentDispositionAttachment(file.Name))
	w.Header().Set("Content-Type", "application/octet-stream")
	http.ServeContent(w, r, file.Name, info.ModTime(), f)
}

// contentDispositionAttachment 生成 attachment 头，兼容非 ASCII 文件名。
func contentDispositionAttachment(filename string) string {
	ascii := strings.Map(func(r rune) rune {
		if r > 127 || r == '"' || r == '\\' {
			return '_'
		}
		return r
	}, filename)
	return fmt.Sprintf(`attachment; filename="%s"; filename*=UTF-8''%s`, ascii, url.PathEscape(filename))
}
