package service

import (
	"testing"
	"time"

	"instant_share/server/internal/domain/room"
)

func TestRoomServiceRequestPairingMergesDevice(t *testing.T) {
	svc := NewService()
	now := time.Date(2026, 7, 20, 10, 0, 0, 0, time.UTC)
	svc.SetNow(func() time.Time { return now })
	svc.EnsureRoom("host", "http://192.168.1.10:8080", "session")

	first, rejoined, err := svc.RequestPairing("peer", "Peer", "http://192.168.1.20:8080")
	if err != nil || rejoined {
		t.Fatalf("first request failed: err=%v rejoined=%v", err, rejoined)
	}
	now = now.Add(10 * time.Second)
	second, rejoined, err := svc.RequestPairing("peer", "Peer 2", "http://192.168.1.21:8080")
	if err != nil || rejoined {
		t.Fatalf("second request failed: err=%v rejoined=%v", err, rejoined)
	}

	pending := svc.Pending()
	if len(pending) != 1 {
		t.Fatalf("pending length = %d, want 1", len(pending))
	}
	if !second.ExpiresAt.After(first.ExpiresAt) {
		t.Fatalf("expires_at was not refreshed")
	}
	if pending[0].DisplayName != "Peer 2" || pending[0].PeerBaseURL != "http://192.168.1.21:8080" {
		t.Fatalf("pending was not refreshed: %#v", pending[0])
	}
}

func TestRoomServiceRequestPairingRejoinsExistingMember(t *testing.T) {
	svc := NewService()
	svc.EnsureRoom("host", "http://192.168.1.10:8080", "session")
	if _, _, err := svc.RequestPairing("peer", "Peer", "http://192.168.1.20:8080"); err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if _, err := svc.Approve("peer"); err != nil {
		t.Fatalf("approve failed: %v", err)
	}

	pending, rejoined, err := svc.RequestPairing("peer", "Peer Renamed", "http://192.168.1.20:8081")
	if err != nil {
		t.Fatalf("rejoin request failed: %v", err)
	}
	if !rejoined {
		t.Fatalf("expected rejoined=true for existing member")
	}
	if len(svc.Pending()) != 0 {
		t.Fatalf("rejoin should not create pending")
	}
	members := svc.Members()
	if len(members) != 1 {
		t.Fatalf("members length = %d, want 1", len(members))
	}
	if members[0].DisplayName != "Peer Renamed" || members[0].PeerBaseURL != "http://192.168.1.20:8081" {
		t.Fatalf("member was not refreshed: %#v", members[0])
	}
	if pending.DisplayName != "Peer Renamed" {
		t.Fatalf("ack pending display = %q", pending.DisplayName)
	}
}

func TestRoomServiceRejectRemovesPending(t *testing.T) {
	svc := NewService()
	svc.EnsureRoom("host", "http://192.168.1.10:8080", "session")
	if _, _, err := svc.RequestPairing("peer", "Peer", "http://192.168.1.20:8080"); err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if err := svc.Reject("peer"); err != nil {
		t.Fatalf("reject failed: %v", err)
	}
	if len(svc.Pending()) != 0 {
		t.Fatalf("pending should be empty after reject")
	}
	if _, err := svc.Approve("peer"); err != room.ErrPairingNotFound {
		t.Fatalf("approve after reject err = %v, want ErrPairingNotFound", err)
	}
}

func TestRoomServiceApproveMovesPendingToMembers(t *testing.T) {
	svc := NewService()
	svc.EnsureRoom("host", "http://192.168.1.10:8080", "session")
	if _, _, err := svc.RequestPairing("peer", "Peer", "http://192.168.1.20:8080"); err != nil {
		t.Fatalf("request failed: %v", err)
	}

	member, err := svc.Approve("peer")
	if err != nil {
		t.Fatalf("approve failed: %v", err)
	}
	if member.DeviceID != "peer" {
		t.Fatalf("member device id = %q", member.DeviceID)
	}
	if len(svc.Pending()) != 0 {
		t.Fatalf("pending was not removed")
	}
	if !svc.IsAuthorizedPeer("peer") {
		t.Fatalf("peer should be authorized")
	}
}

func TestRoomServiceSweepExpired(t *testing.T) {
	svc := NewService()
	now := time.Date(2026, 7, 20, 10, 0, 0, 0, time.UTC)
	svc.SetNow(func() time.Time { return now })
	svc.EnsureRoom("host", "http://192.168.1.10:8080", "session")
	if _, _, err := svc.RequestPairing("peer", "Peer", "http://192.168.1.20:8080"); err != nil {
		t.Fatalf("request failed: %v", err)
	}

	now = now.Add(room.PairingTTL + time.Second)
	expired := svc.SweepExpired()
	if len(expired) != 1 || expired[0] != "peer" {
		t.Fatalf("expired = %#v", expired)
	}
	if len(svc.Pending()) != 0 {
		t.Fatalf("expired pending was not removed")
	}
}

func TestRoomServiceRemoveMemberClearsCatalog(t *testing.T) {
	svc := NewService()
	svc.EnsureRoom("host", "http://192.168.1.10:8080", "session")
	if _, _, err := svc.RequestPairing("peer", "Peer", "http://192.168.1.20:8080"); err != nil {
		t.Fatalf("request failed: %v", err)
	}
	if _, err := svc.Approve("peer"); err != nil {
		t.Fatalf("approve failed: %v", err)
	}
	svc.SetOwnerFiles("host", "Host", "http://192.168.1.10:8080", []room.SharedFileMeta{{
		ID: "a", Name: "a.txt", Size: 1, DownloadPath: "/api/v1/share/files/a/download",
	}})
	svc.SetOwnerFiles("peer", "Peer", "http://192.168.1.20:8080", []room.SharedFileMeta{{
		ID: "b", Name: "b.txt", Size: 2, DownloadPath: "/api/v1/share/files/b/download",
	}})

	catalog, revision, removed := svc.RemoveMember("peer")
	if !removed {
		t.Fatalf("expected member removed")
	}
	if svc.IsAuthorizedPeer("peer") {
		t.Fatalf("peer should no longer be authorized")
	}
	if len(svc.Members()) != 0 {
		t.Fatalf("members = %#v, want empty", svc.Members())
	}
	if len(catalog) != 1 || catalog[0].OwnerID != "host" {
		t.Fatalf("catalog after remove = %#v", catalog)
	}
	if revision < 1 {
		t.Fatalf("revision = %d", revision)
	}
}

func TestRoomServiceSetOwnerFilesAggregates(t *testing.T) {
	svc := NewService()
	svc.EnsureRoom("host", "http://192.168.1.10:8080", "session")

	_, rev1 := svc.SetOwnerFiles("host", "Host", "http://192.168.1.10:8080", []room.SharedFileMeta{{
		ID: "a", Name: "a.txt", Size: 1, DownloadPath: "/api/v1/share/files/a/download",
	}})
	catalog, rev2 := svc.SetOwnerFiles("peer", "Peer", "http://192.168.1.20:8080", []room.SharedFileMeta{{
		ID: "b", Name: "b.txt", Size: 2, DownloadPath: "/api/v1/share/files/b/download",
	}})

	if rev1 != 1 || rev2 != 2 {
		t.Fatalf("revisions = %d, %d", rev1, rev2)
	}
	if len(catalog) != 2 {
		t.Fatalf("catalog length = %d, want 2", len(catalog))
	}
	if catalog[0].OwnerID != "host" || catalog[1].OwnerID != "peer" {
		t.Fatalf("unexpected catalog: %#v", catalog)
	}
}

func TestRoomServiceCloseClearsState(t *testing.T) {
	svc := NewService()
	svc.EnsureRoom("host", "http://192.168.1.10:8080", "session")
	_, _, _ = svc.RequestPairing("peer", "Peer", "http://192.168.1.20:8080")
	_, _ = svc.Approve("peer")
	svc.SetOwnerFiles("peer", "Peer", "http://192.168.1.20:8080", []room.SharedFileMeta{{
		ID: "b", Name: "b.txt", Size: 2, DownloadPath: "/api/v1/share/files/b/download",
	}})

	svc.Close()
	catalog, revision := svc.Catalog()
	if len(catalog) != 0 || revision != 0 || len(svc.Members()) != 0 || len(svc.Pending()) != 0 {
		t.Fatalf("room state was not cleared")
	}
	if _, _, err := svc.RequestPairing("peer", "Peer", "http://192.168.1.20:8080"); err != room.ErrRoomNotActive {
		t.Fatalf("request after close err = %v, want ErrRoomNotActive", err)
	}
}
