package public_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	sharememory "instant_share/server/internal/adapter/share/memory"
	roommemory "instant_share/server/internal/adapter/room/memory"
	roomsvc "instant_share/server/internal/application/room/service"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/internal/domain/room"
	"instant_share/server/internal/domain/share"
	"instant_share/server/internal/delivery/res"
	"instant_share/server/internal/interfaces/public"
)

func TestHandleShareStatusHostWithMemberIgnoresMirror(t *testing.T) {
	shareStore := sharememory.NewStore(8080)
	shareSvc := sharesvc.NewService(shareStore, "127.0.0.1", 8080)
	roomSvc := roomsvc.NewService()
	roomSvc.EnsureRoom("host", "http://192.168.1.10:8080", "session-1")
	if _, err := roomSvc.RequestPairing("peer-a", "Peer A", "http://192.168.1.20:8080"); err != nil {
		t.Fatalf("RequestPairing failed: %v", err)
	}
	if _, err := roomSvc.Approve("peer-a"); err != nil {
		t.Fatalf("Approve failed: %v", err)
	}
	roomSvc.SetOwnerFiles("host", "Host", "http://192.168.1.10:8080", []room.SharedFileMeta{
		{ID: "room-file", Name: "room.txt", Size: 10, DownloadPath: "/api/v1/share/files/room-file/download"},
	})
	mirrorStore := roommemory.NewPublicMirror()
	mirrorSvc := roomsvc.NewMirrorService(mirrorStore)
	mirrorSvc.Set([]room.SharedEntry{
		{
			ID:           "stale-mirror-file",
			Name:         "stale.txt",
			Size:         1,
			BaseURL:      "http://192.168.1.20:8080",
			DownloadPath: "/api/v1/share/files/stale-mirror-file/download",
		},
	})

	h := public.NewController(shareSvc, roomSvc, mirrorSvc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/status", nil)
	rec := httptest.NewRecorder()
	mux := http.NewServeMux()
	h.Register(mux)
	mux.ServeHTTP(rec, req)

	var resp res.APIResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response failed: %v", err)
	}
	dataBytes, err := json.Marshal(resp.Data)
	if err != nil {
		t.Fatalf("marshal response data failed: %v", err)
	}
	var status share.PublicStatus
	if err := json.Unmarshal(dataBytes, &status); err != nil {
		t.Fatalf("decode PublicShareStatus failed: %v", err)
	}

	if len(status.Files) != 1 || status.Files[0].ID != "room-file" {
		t.Fatalf("Files = %#v, want only room-file — Host with members must use room catalog and ignore mirror", status.Files)
	}
}

func TestHandleShareStatusUsesMirrorWhenNotHost(t *testing.T) {
	shareStore := sharememory.NewStore(8080)
	shareSvc := sharesvc.NewService(shareStore, "127.0.0.1", 8080)
	roomSvc := roomsvc.NewService()
	mirrorStore := roommemory.NewPublicMirror()
	mirrorSvc := roomsvc.NewMirrorService(mirrorStore)
	mirrorSvc.Set([]room.SharedEntry{
		{
			ID:           "mirror-file",
			Name:         "mirror.txt",
			Size:         1,
			BaseURL:      "http://192.168.1.20:8080",
			DownloadPath: "/api/v1/share/files/mirror-file/download",
		},
	})

	h := public.NewController(shareSvc, roomSvc, mirrorSvc)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/share/status", nil)
	rec := httptest.NewRecorder()
	mux := http.NewServeMux()
	h.Register(mux)
	mux.ServeHTTP(rec, req)

	var resp res.APIResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response failed: %v", err)
	}
	dataBytes, err := json.Marshal(resp.Data)
	if err != nil {
		t.Fatalf("marshal response data failed: %v", err)
	}
	var status share.PublicStatus
	if err := json.Unmarshal(dataBytes, &status); err != nil {
		t.Fatalf("decode PublicShareStatus failed: %v", err)
	}

	if len(status.Files) != 1 || status.Files[0].ID != "mirror-file" {
		t.Fatalf("Files = %#v, want mirror-file when not Host", status.Files)
	}
}
