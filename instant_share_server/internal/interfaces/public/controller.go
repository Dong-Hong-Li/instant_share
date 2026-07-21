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
	share  fs.FS
	files  *sharesvc.Service
	room   *roomsvc.Service
	mirror *roomsvc.MirrorService
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

// Register 注册路由。
func (c *Controller) Register(mux *http.ServeMux) {
	mux.HandleFunc("/", c.handleRoot)
	mux.HandleFunc("/share", c.handleShareEntry)
	mux.Handle("/share/", c.handleShareStatic())
	mux.HandleFunc("/api/v1/share/status", c.handleShareStatus)
	mux.HandleFunc("/api/v1/share/files/batch/download", c.handleBatchDownload)
	mux.HandleFunc("/api/v1/share/files/", c.handleShareFileDownload)
}

func (c *Controller) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share/", http.StatusFound)
}

func (c *Controller) handleShareEntry(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/share" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share/", http.StatusFound)
}

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

func resolveLocalBaseURL(room *roomsvc.Service, share *sharesvc.Service) string {
	if room != nil {
		if base := room.HostBaseURL(); base != "" {
			return base
		}
	}
	return share.HTTPBase()
}

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

func contentDispositionAttachment(filename string) string {
	ascii := strings.Map(func(r rune) rune {
		if r > 127 || r == '"' || r == '\\' {
			return '_'
		}
		return r
	}, filename)
	return fmt.Sprintf(`attachment; filename="%s"; filename*=UTF-8''%s`, ascii, url.PathEscape(filename))
}
