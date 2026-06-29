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
	share fs.FS
	files *service.ShareService
}

func NewPublicHandler(share *service.ShareService) *PublicHandler {
	return &PublicHandler{
		share: webassets.FS(),
		files: share,
	}
}

func (h *PublicHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("/", h.handleRoot)
	mux.HandleFunc("/share", h.handleShareEntry)
	mux.Handle("/share/", h.handleShareStatic())
	mux.HandleFunc("/api/v1/share/status", h.handleShareStatus)
	mux.HandleFunc("/api/v1/share/files/batch/download", h.handleBatchDownload)
	mux.HandleFunc("/api/v1/share/files/", h.handleShareFileDownload)
}

func (h *PublicHandler) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share/", http.StatusFound)
}

func (h *PublicHandler) handleShareEntry(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/share" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share/", http.StatusFound)
}

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

func (h *PublicHandler) handleShareStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}

	status := h.files.Status()
	writeJSON(w, http.StatusOK, model.APIResponse{
		OK:   true,
		Data: toPublicShareStatus(status),
	})
}

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

func contentDispositionAttachment(filename string) string {
	ascii := strings.Map(func(r rune) rune {
		if r > 127 || r == '"' || r == '\\' {
			return '_'
		}
		return r
	}, filename)
	return fmt.Sprintf(`attachment; filename="%s"; filename*=UTF-8''%s`, ascii, url.PathEscape(filename))
}
