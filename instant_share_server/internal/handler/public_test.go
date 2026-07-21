package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"instant_share/server/internal/model"
	"instant_share/server/internal/service"
)

// TestHandleShareStatusHostWithMemberIgnoresMirror 覆盖新的权威 Host 判定：当本机是已接纳
// 成员（room.Members() 非空）的房间 Host 时，公开状态应以 RoomService.Catalog 为准，并忽略
// 任何残留的 Peer 镜像目录。
func TestHandleShareStatusHostWithMemberIgnoresMirror(t *testing.T) {
	share := service.NewShareService("127.0.0.1", 8080)
	room := service.NewRoomService()
	room.EnsureRoom("host", "http://192.168.1.10:8080", "session-1") // 本机是房间 Host。
	// 通过配对审批一个 Peer 成员，使 room.Members() 非空 —— 这才是「权威 Host」。
	if _, err := room.RequestPairing("peer-a", "Peer A", "http://192.168.1.20:8080"); err != nil {
		t.Fatalf("RequestPairing failed: %v", err)
	}
	if _, err := room.Approve("peer-a"); err != nil {
		t.Fatalf("Approve failed: %v", err)
	}
	room.SetOwnerFiles("host", "Host", "http://192.168.1.10:8080", []model.SharedFileMeta{
		{ID: "room-file", Name: "room.txt", Size: 10, DownloadPath: "/api/v1/share/files/room-file/download"},
	})
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

	if len(status.Files) != 1 || status.Files[0].ID != "room-file" {
		t.Fatalf("Files = %#v, want only room-file — Host with members must use room catalog and ignore mirror", status.Files)
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
