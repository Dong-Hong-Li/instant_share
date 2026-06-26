package util

import (
	"mime"
	"path/filepath"
)

// ContentTypeByName 根据文件名推断 MIME 类型。
func ContentTypeByName(name string) string {
	ext := filepath.Ext(name)
	if ext == "" {
		return "application/octet-stream"
	}
	if t := mime.TypeByExtension(ext); t != "" {
		return t
	}
	return "application/octet-stream"
}
