package handler

import (
	"testing"

	"instant_share/server/internal/model"
)

func TestBuildPublicShareStatusLocalOnly(t *testing.T) {
	share := model.ShareStatus{
		Active:    true,
		SessionID: "session-1",
		BaseURL:   "http://192.168.1.10:8080",
		Files: []model.ShareFile{
			{ID: "f1", Name: "local.txt", Size: 100},
		},
		Articles: []model.ShareArticle{
			{ID: "a1", Title: "Article", Content: "body"},
		},
	}

	got := buildPublicShareStatus(share, nil, nil, share.BaseURL)

	if !got.Active {
		t.Fatalf("Active = false, want true")
	}
	if got.SessionID != "session-1" {
		t.Fatalf("SessionID = %q, want session-1", got.SessionID)
	}
	if len(got.Files) != 1 {
		t.Fatalf("len(Files) = %d, want 1", len(got.Files))
	}
	if got.Files[0].DownloadURL != "/api/v1/share/files/f1/download" {
		t.Fatalf("DownloadURL = %q, want relative local path", got.Files[0].DownloadURL)
	}
	if got.Files[0].OwnerDisplayName != "" {
		t.Fatalf("OwnerDisplayName = %q, want empty for local share files", got.Files[0].OwnerDisplayName)
	}
	if len(got.Articles) != 1 || got.Articles[0].ID != "a1" {
		t.Fatalf("Articles = %#v, want one article a1", got.Articles)
	}
}

// TestBuildPublicShareStatusPrefersMirrorOverRoom 覆盖新的优先级：当 Peer 镜像目录与本机
// 房间目录同时存在时，应优先使用镜像（Peer 聚合到的完整跨设备目录），避免 Peer 自己开始
// 本地分享、把自身文件写入 RoomService("host") 后，公开状态退化为只剩本机文件。真正的 Host
// （已有成员）由调用方在 handler 层传入 mirror=nil 来强制走房间目录，另有用例覆盖。
func TestBuildPublicShareStatusPrefersMirrorOverRoom(t *testing.T) {
	share := model.ShareStatus{
		Active: true,
		Files: []model.ShareFile{
			{ID: "local", Name: "local.txt", Size: 1},
		},
	}
	roomCatalog := []model.SharedEntry{
		{
			ID:               "room-file",
			Name:             "room.txt",
			Size:             10,
			OwnerID:          "host",
			OwnerDisplayName: "Host",
			BaseURL:          "http://192.168.1.10:8080",
			DownloadPath:     "/api/v1/share/files/room-file/download",
		},
	}
	mirror := []model.SharedEntry{
		{
			ID:               "mirror-a",
			Name:             "a.txt",
			Size:             20,
			OwnerDisplayName: "Peer A",
			BaseURL:          "http://192.168.1.20:8080",
			DownloadPath:     "/api/v1/share/files/mirror-a/download",
		},
		{
			ID:               "mirror-b",
			Name:             "b.txt",
			Size:             30,
			OwnerDisplayName: "Peer B",
			BaseURL:          "http://192.168.1.10:8080",
			DownloadPath:     "/api/v1/share/files/mirror-b/download",
		},
	}

	got := buildPublicShareStatus(share, roomCatalog, mirror, "http://192.168.1.10:8080")

	if len(got.Files) != 2 {
		t.Fatalf("len(Files) = %d, want 2 from mirror (A+B)", len(got.Files))
	}
	if got.Files[0].ID != "mirror-a" || got.Files[1].ID != "mirror-b" {
		t.Fatalf("Files = %#v, want mirror entries mirror-a + mirror-b", got.Files)
	}
}

func TestBuildPublicShareStatusMirrorWhenNoRoom(t *testing.T) {
	share := model.ShareStatus{Active: true}
	mirror := []model.SharedEntry{
		{
			ID:               "mirror-file",
			Name:             "mirror.txt",
			Size:             20,
			OwnerDisplayName: "Peer",
			BaseURL:          "http://192.168.1.10:8080",
			DownloadPath:     "/api/v1/share/files/mirror-file/download",
		},
	}

	got := buildPublicShareStatus(share, nil, mirror, "http://192.168.1.10:8080")

	if len(got.Files) != 1 {
		t.Fatalf("len(Files) = %d, want 1 from mirror", len(got.Files))
	}
	if got.Files[0].ID != "mirror-file" {
		t.Fatalf("Files[0].ID = %q, want mirror-file", got.Files[0].ID)
	}
	if got.Files[0].OwnerDisplayName != "Peer" {
		t.Fatalf("OwnerDisplayName = %q, want Peer", got.Files[0].OwnerDisplayName)
	}
}

func TestBuildPublicShareStatusRemoteAbsoluteURL(t *testing.T) {
	share := model.ShareStatus{Active: true}
	catalog := []model.SharedEntry{
		{
			ID:               "remote-file",
			Name:             "remote.txt",
			Size:             50,
			OwnerDisplayName: "Peer",
			BaseURL:          "http://192.168.1.20:8080",
			DownloadPath:     "/api/v1/share/files/remote-file/download",
		},
	}

	got := buildPublicShareStatus(share, catalog, nil, "http://192.168.1.10:8080")

	if len(got.Files) != 1 {
		t.Fatalf("len(Files) = %d, want 1", len(got.Files))
	}
	wantURL := "http://192.168.1.20:8080/api/v1/share/files/remote-file/download"
	if got.Files[0].DownloadURL != wantURL {
		t.Fatalf("DownloadURL = %q, want %q", got.Files[0].DownloadURL, wantURL)
	}
}

func TestBuildPublicShareStatusActiveWhenFilesFromCatalog(t *testing.T) {
	share := model.ShareStatus{
		Active: false,
		Files:  nil,
	}
	roomCatalog := []model.SharedEntry{
		{
			ID:           "room-file",
			Name:         "room.txt",
			Size:         10,
			BaseURL:      "http://192.168.1.10:8080",
			DownloadPath: "/api/v1/share/files/room-file/download",
		},
	}

	got := buildPublicShareStatus(share, roomCatalog, nil, "http://192.168.1.10:8080")

	if !got.Active {
		t.Fatalf("Active = false, want true when catalog has files")
	}
}
