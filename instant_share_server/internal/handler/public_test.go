package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"instant_share/server/internal/model"
	"instant_share/server/internal/service"
)

// TestHandleShareStatusHostIgnoresMirrorWhenCatalogEmpty 覆盖 P2：Host 构建公开状态时应以
// RoomService 为准，忽略 Peer 镜像——即便房间目录当前为空（如刚关闭分享后的瞬间），也不能
// 回退到可能过期的镜像数据。
func TestHandleShareStatusHostIgnoresMirrorWhenCatalogEmpty(t *testing.T) {
	share := service.NewShareService("127.0.0.1", 8080)
	room := service.NewRoomService()
	room.EnsureRoom("host", "http://192.168.1.10:8080", "session-1") // 本机是房间 Host。
	mirror := service.NewPublicRoomCatalog()
	mirror.Set([]model.SharedEntry{
		{
			ID:           "stale-mirror-file",
			Name:         "stale.txt",
			Size:         1,
			BaseURL:      "http://192.168.1.20:8080",
			DownloadPath: "/api/v1/share/files/stale-mirror-file/download",
		},
	})

	h := &PublicHandler{files: share, room: room, mirror: mirror}

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/status", nil)
	rec := httptest.NewRecorder()
	h.handleShareStatus(rec, req)

	var resp model.APIResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response failed: %v", err)
	}
	dataBytes, err := json.Marshal(resp.Data)
	if err != nil {
		t.Fatalf("marshal response data failed: %v", err)
	}
	var status model.PublicShareStatus
	if err := json.Unmarshal(dataBytes, &status); err != nil {
		t.Fatalf("decode PublicShareStatus failed: %v", err)
	}

	if len(status.Files) != 0 {
		t.Fatalf("Files = %#v, want empty — Host must ignore Peer mirror even when room catalog is empty", status.Files)
	}
	if status.Active {
		t.Fatalf("Active = true, want false — mirror-derived activity must not leak on Host")
	}
}

// TestHandleShareStatusUsesMirrorWhenNotHost 对照用例：非 Host（RoomService 无 HostBaseURL，
// 即 Peer 镜像场景）时，镜像目录仍应正常展示。
func TestHandleShareStatusUsesMirrorWhenNotHost(t *testing.T) {
	share := service.NewShareService("127.0.0.1", 8080)
	room := service.NewRoomService() // 未 EnsureRoom：本机不是 Host。
	mirror := service.NewPublicRoomCatalog()
	mirror.Set([]model.SharedEntry{
		{
			ID:           "mirror-file",
			Name:         "mirror.txt",
			Size:         1,
			BaseURL:      "http://192.168.1.20:8080",
			DownloadPath: "/api/v1/share/files/mirror-file/download",
		},
	})

	h := &PublicHandler{files: share, room: room, mirror: mirror}

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/status", nil)
	rec := httptest.NewRecorder()
	h.handleShareStatus(rec, req)

	var resp model.APIResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response failed: %v", err)
	}
	dataBytes, err := json.Marshal(resp.Data)
	if err != nil {
		t.Fatalf("marshal response data failed: %v", err)
	}
	var status model.PublicShareStatus
	if err := json.Unmarshal(dataBytes, &status); err != nil {
		t.Fatalf("decode PublicShareStatus failed: %v", err)
	}

	if len(status.Files) != 1 || status.Files[0].ID != "mirror-file" {
		t.Fatalf("Files = %#v, want mirror-file when not Host", status.Files)
	}
}
