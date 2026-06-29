package web

import (
	"embed"
	"io/fs"
	"net/http"
)

//go:embed dist/*
var dist embed.FS

// FS 返回嵌入的前端构建产物根目录。
func FS() fs.FS {
	sub, err := fs.Sub(dist, "dist")
	if err != nil {
		panic("web: invalid embedded dist: " + err.Error())
	}
	return sub
}

// FileServer 返回用于 /share/ 前缀的静态文件处理器。
func FileServer() http.Handler {
	return http.FileServer(http.FS(FS()))
}
