package handler

import (
	"html/template"
	"net/http"

	"instant_share/server/internal/service"
	"instant_share/server/internal/util"
)

// PublicHandler 接收者只读页面：通过 HTTP 查看当前分享的文件列表。
type PublicHandler struct {
	share *service.ShareService
}

func NewPublicHandler(share *service.ShareService) *PublicHandler {
	return &PublicHandler{share: share}
}

func (h *PublicHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("/", h.handleRoot)
	mux.HandleFunc("/share", h.handleSharePage)
}

func (h *PublicHandler) handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, "/share", http.StatusFound)
}

func (h *PublicHandler) handleSharePage(w http.ResponseWriter, r *http.Request) {
	status := h.share.Status()

	type pageFile struct {
		Name     string
		SizeText string
	}

	files := make([]pageFile, 0, len(status.Files))
	for _, file := range status.Files {
		files = append(files, pageFile{
			Name:     file.Name,
			SizeText: util.FormatSize(file.Size),
		})
	}

	data := struct {
		Title  string
		Active bool
		Files  []pageFile
	}{
		Title:  "Instant Share",
		Active: status.Active,
		Files:  files,
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := sharePageTemplate.Execute(w, data); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

var sharePageTemplate = template.Must(template.New("share").Parse(`<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{{ .Title }}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f5f6f8; margin: 0; color: #1f2937; }
    .wrap { max-width: 720px; margin: 0 auto; padding: 32px 16px; }
    h1 { margin: 0 0 8px; font-size: 28px; }
    .hint { color: #64748b; font-size: 14px; margin-bottom: 24px; }
    .card { background: #fff; border-radius: 12px; box-shadow: 0 8px 24px rgba(15, 23, 42, 0.08); overflow: hidden; }
    .item { padding: 16px 20px; border-top: 1px solid #eef2f7; }
    .item:first-child { border-top: 0; }
    .name { font-weight: 600; word-break: break-all; }
    .size { color: #64748b; font-size: 14px; margin-top: 4px; }
    .empty { color: #64748b; }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>{{ .Title }}</h1>
    {{ if .Active }}
    <div class="hint">当前分享中的文件（只读浏览，暂不支持操作）</div>
    <div class="card">
      {{ range .Files }}
      <div class="item">
        <div class="name">{{ .Name }}</div>
        <div class="size">{{ .SizeText }}</div>
      </div>
      {{ else }}
      <div class="item empty">暂无文件</div>
      {{ end }}
    </div>
    {{ else }}
    <div class="hint">当前没有进行中的分享</div>
    <div class="card">
      <div class="item empty">请等待发起者开启分享</div>
    </div>
    {{ end }}
  </div>
</body>
</html>`))
