package service

import (
	"testing"

	"instant_share/server/internal/domain/room"
	"instant_share/server/internal/domain/share"
)

func TestBuildPublicShareStatusLocalOnly(t *testing.T) {
	status := share.Status{
		Active:    true,
		SessionID: "session-1",
		BaseURL:   "http://192.168.1.10:8080",
		Files: []share.ShareFile{
			{ID: "f1", Name: "local.txt", Size: 100},
		},
		Articles: []share.ShareArticle{
			{ID: "a1", Title: "Article", Content: "body"},
		},
	}

	got := BuildPublicShareStatus(status, nil, nil, status.BaseURL)

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

func TestBuildPublicShareStatusPrefersMirrorOverRoom(t *testing.T) {
	status := share.Status{
		Active: true,
		Files: []share.ShareFile{
			{ID: "local", Name: "local.txt", Size: 1},
		},
	}
	roomCatalog := []room.SharedEntry{
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
	mirror := []room.SharedEntry{
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

	got := BuildPublicShareStatus(status, roomCatalog, mirror, "http://192.168.1.10:8080")

	if len(got.Files) != 2 {
		t.Fatalf("len(Files) = %d, want 2 from mirror (A+B)", len(got.Files))
	}
	if got.Files[0].ID != "mirror-a" || got.Files[1].ID != "mirror-b" {
		t.Fatalf("Files = %#v, want mirror entries mirror-a + mirror-b", got.Files)
	}
}

func TestBuildPublicShareStatusMirrorWhenNoRoom(t *testing.T) {
	status := share.Status{Active: true}
	mirror := []room.SharedEntry{
		{
			ID:               "mirror-file",
			Name:             "mirror.txt",
			Size:             20,
			OwnerDisplayName: "Peer",
			BaseURL:          "http://192.168.1.10:8080",
			DownloadPath:     "/api/v1/share/files/mirror-file/download",
		},
	}

	got := BuildPublicShareStatus(status, nil, mirror, "http://192.168.1.10:8080")

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
	status := share.Status{Active: true}
	catalog := []room.SharedEntry{
		{
			ID:               "remote-file",
			Name:             "remote.txt",
			Size:             50,
			OwnerDisplayName: "Peer",
			BaseURL:          "http://192.168.1.20:8080",
			DownloadPath:     "/api/v1/share/files/remote-file/download",
		},
	}

	got := BuildPublicShareStatus(status, catalog, nil, "http://192.168.1.10:8080")

	if len(got.Files) != 1 {
		t.Fatalf("len(Files) = %d, want 1", len(got.Files))
	}
	wantURL := "http://192.168.1.20:8080/api/v1/share/files/remote-file/download"
	if got.Files[0].DownloadURL != wantURL {
		t.Fatalf("DownloadURL = %q, want %q", got.Files[0].DownloadURL, wantURL)
	}
}

func TestBuildPublicShareStatusActiveWhenFilesFromCatalog(t *testing.T) {
	status := share.Status{Active: false, Files: nil}
	roomCatalog := []room.SharedEntry{
		{
			ID:           "room-file",
			Name:         "room.txt",
			Size:         10,
			BaseURL:      "http://192.168.1.10:8080",
			DownloadPath: "/api/v1/share/files/room-file/download",
		},
	}

	got := BuildPublicShareStatus(status, roomCatalog, nil, "http://192.168.1.10:8080")

	if !got.Active {
		t.Fatalf("Active = false, want true when catalog has files")
	}
}

func TestIsAuthoritativeHost(t *testing.T) {
	if IsAuthoritativeHost(0) {
		t.Fatalf("0 members should not be authoritative host")
	}
	if !IsAuthoritativeHost(1) {
		t.Fatalf("1+ members should be authoritative host")
	}
}
