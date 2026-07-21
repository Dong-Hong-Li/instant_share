package handler

import (
	"archive/zip"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"instant_share/server/internal/model"
)

// handleBatchDownload 处理批量下载。
func (h *PublicHandler) handleBatchDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w)
		return
	}

	status := h.files.Status()
	if !status.Active {
		writeError(w, http.StatusNotFound, "share is not active")
		return
	}

	rawIDs := strings.TrimSpace(r.URL.Query().Get("ids"))
	if rawIDs == "" {
		writeError(w, http.StatusBadRequest, "ids required")
		return
	}

	idSet := make(map[string]struct{})
	for _, part := range strings.Split(rawIDs, ",") {
		id := strings.TrimSpace(part)
		if id == "" {
			continue
		}
		idSet[id] = struct{}{}
	}
	if len(idSet) == 0 {
		writeError(w, http.StatusBadRequest, "ids required")
		return
	}

	files := make([]model.ShareFile, 0, len(idSet))
	for _, file := range status.Files {
		if _, ok := idSet[file.ID]; ok {
			files = append(files, file)
		}
	}
	if len(files) == 0 {
		writeError(w, http.StatusNotFound, "no files matched")
		return
	}

	for _, file := range files {
		if _, err := os.Stat(file.Path); err != nil {
			writeError(w, http.StatusNotFound, "file not found")
			return
		}
	}

	filename := fmt.Sprintf("share-files-%s.zip", time.Now().Format("20060102-150405"))
	w.Header().Set("Content-Type", "application/zip")
	w.Header().Set("Content-Disposition", contentDispositionAttachment(filename))

	zw := zip.NewWriter(w)
	defer func() { _ = zw.Close() }()

	usedNames := make(map[string]int)
	for _, file := range files {
		if err := appendFileToZip(zw, file, usedNames); err != nil {
			writeError(w, http.StatusInternalServerError, "failed to create archive")
			return
		}
	}
}

// appendFileToZip 追加文件到压缩包。
func appendFileToZip(zw *zip.Writer, file model.ShareFile, usedNames map[string]int) error {
	src, err := os.Open(file.Path)
	if err != nil {
		return err
	}
	defer src.Close()

	info, err := src.Stat()
	if err != nil {
		return err
	}
	if info.IsDir() {
		return fmt.Errorf("directory not supported: %q", file.Path)
	}

	entryName := uniqueZipEntryName(file.Name, usedNames)
	writer, err := zw.Create(entryName)
	if err != nil {
		return err
	}

	_, err = io.Copy(writer, src)
	return err
}

// uniqueZipEntryName 生成唯一压缩包文件名。
func uniqueZipEntryName(name string, usedNames map[string]int) string {
	if count, exists := usedNames[name]; !exists {
		usedNames[name] = 1
		return name
	} else {
		next := count + 1
		usedNames[name] = next
		ext := filepath.Ext(name)
		base := strings.TrimSuffix(name, ext)
		return fmt.Sprintf("%s (%d)%s", base, next, ext)
	}
}
