package share_test

import (
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	gws "github.com/gorilla/websocket"

	"instant_share/server/config"
	sharememory "instant_share/server/internal/adapter/share/memory"
	roommemory "instant_share/server/internal/adapter/room/memory"
	gatewaysvc "instant_share/server/internal/application/gateway/service"
	roomsvc "instant_share/server/internal/application/room/service"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/internal/domain/room"
	"instant_share/server/internal/domain/share"
	infraws "instant_share/server/internal/infrastructure/websocket"
	roomif "instant_share/server/internal/interfaces/room"
	shareif "instant_share/server/internal/interfaces/share"
	"instant_share/server/internal/interfaces/request"
)

type wsTestFrame struct {
	Type      string          `json:"type"`
	RequestID string          `json:"request_id,omitempty"`
	Code      int             `json:"code"`
	Message   string          `json:"message"`
	Data      json.RawMessage `json:"data,omitempty"`
}

func dialTestWS(t *testing.T, wsURL, role, deviceID string) *gws.Conn {
	t.Helper()
	u := fmt.Sprintf("%s?role=%s&device_id=%s", wsURL, role, deviceID)
	conn, _, err := gws.DefaultDialer.Dial(u, nil)
	if err != nil {
		t.Fatalf("dial role=%s failed: %v", role, err)
	}
	return conn
}

func readFrameOfType(t *testing.T, conn *gws.Conn, wantType string) wsTestFrame {
	t.Helper()
	deadline := time.Now().Add(3 * time.Second)
	for {
		_ = conn.SetReadDeadline(deadline)
		var frame wsTestFrame
		if err := conn.ReadJSON(&frame); err != nil {
			t.Fatalf("read frame (want %q) failed: %v", wantType, err)
		}
		if frame.Type == wantType {
			return frame
		}
		if time.Now().After(deadline) {
			t.Fatalf("timed out waiting for frame type %q, last seen %q", wantType, frame.Type)
		}
	}
}

func drainExtraShareStatus(t *testing.T, conn *gws.Conn) {
	t.Helper()
	deadline := time.Now().Add(200 * time.Millisecond)
	for {
		_ = conn.SetReadDeadline(deadline)
		var frame wsTestFrame
		if err := conn.ReadJSON(&frame); err != nil {
			return
		}
	}
}

func readLatestShareStatusAfter(t *testing.T, conn *gws.Conn, trigger func()) share.PublicStatus {
	t.Helper()
	trigger()
	deadline := time.Now().Add(3 * time.Second)
	var last share.PublicStatus
	for {
		_ = conn.SetReadDeadline(deadline)
		var frame wsTestFrame
		if err := conn.ReadJSON(&frame); err != nil {
			break
		}
		if frame.Type != "share.status" {
			continue
		}
		if err := json.Unmarshal(frame.Data, &last); err != nil {
			t.Fatalf("decode share.status failed: %v", err)
		}
	}
	return last
}

func sendPacket(t *testing.T, conn *gws.Conn, packetType, requestID string, data any) {
	t.Helper()
	raw, err := json.Marshal(data)
	if err != nil {
		t.Fatalf("marshal packet data failed: %v", err)
	}
	packet := infraws.Packet{Type: packetType, RequestID: requestID, Data: raw}
	if data == nil {
		packet.Data = nil
	}
	if err := conn.WriteJSON(packet); err != nil {
		t.Fatalf("write packet %q failed: %v", packetType, err)
	}
}

type wsTestEnv struct {
	share  *sharesvc.Service
	room   *roomsvc.Service
	mirror *roomsvc.MirrorService
	roomWS *roomif.WSController
	shareWS *shareif.WSController
	ws     *infraws.Client
}

func newWSTestEnv(t *testing.T) *wsTestEnv {
	t.Helper()
	shareStore := sharememory.NewStore(0)
	shareSvc := sharesvc.NewService(shareStore, "127.0.0.1", 0)
	roomSvc := roomsvc.NewService()
	mirrorStore := roommemory.NewPublicMirror()
	mirrorSvc := roomsvc.NewMirrorService(mirrorStore)
	wsClient := infraws.NewClient(config.DefaultWebSocketConfig())

	roomWS := roomif.NewWSController(roomSvc, mirrorSvc, wsClient)
	roomWS.Register(wsClient)

	shareWS := shareif.NewWSController(shareSvc, roomSvc, mirrorSvc, wsClient)
	shareWS.SetRoomSyncer(roomWS)
	shareWS.Register(wsClient)

	authSvc := gatewaysvc.NewAuthenticate()
	wsClient.SetAuthFunc(authSvc.Authenticate)

	roomSvc.SetHooks(
		func() {
			roomWS.BroadcastCatalogUpdated()
			shareWS.BroadcastShareStatus()
		},
		func() {
			roomWS.BroadcastPendingUpdated()
		},
	)

	return &wsTestEnv{
		share:   shareSvc,
		room:    roomSvc,
		mirror:  mirrorSvc,
		roomWS:  roomWS,
		shareWS: shareWS,
		ws:      wsClient,
	}
}

func TestHandleShareStopBroadcastsAfterRoomClose(t *testing.T) {
	tmpFile, err := os.CreateTemp(t.TempDir(), "share-*.txt")
	if err != nil {
		t.Fatalf("create temp file failed: %v", err)
	}
	if _, err := tmpFile.WriteString("hello"); err != nil {
		t.Fatalf("write temp file failed: %v", err)
	}
	_ = tmpFile.Close()

	env := newWSTestEnv(t)
	server := httptest.NewServer(env.ws)
	defer server.Close()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	adminConn := dialTestWS(t, wsURL, infraws.RoleAdmin, "admin-1")
	defer adminConn.Close()
	readFrameOfType(t, adminConn, "auth_ack")

	viewerConn := dialTestWS(t, wsURL, infraws.RoleViewer, "viewer-1")
	defer viewerConn.Close()
	readFrameOfType(t, viewerConn, "auth_ack")

	initial := readFrameOfType(t, viewerConn, "share.status")
	var initialStatus share.PublicStatus
	if err := json.Unmarshal(initial.Data, &initialStatus); err != nil {
		t.Fatalf("decode initial share.status failed: %v", err)
	}
	if initialStatus.Active {
		t.Fatalf("initial status Active = true, want false before any share starts")
	}

	sendPacket(t, adminConn, "share.start", "req-start", request.StartShareRequest{
		Files: []share.ShareFile{{Path: tmpFile.Name()}},
	})
	readFrameOfType(t, adminConn, "share.start_ack")

	started := readFrameOfType(t, viewerConn, "share.status")
	drainExtraShareStatus(t, viewerConn)
	var startedStatus share.PublicStatus
	if err := json.Unmarshal(started.Data, &startedStatus); err != nil {
		t.Fatalf("decode started share.status failed: %v", err)
	}
	if !startedStatus.Active || len(startedStatus.Files) != 1 {
		t.Fatalf("started status = %#v, want Active=true with 1 file", startedStatus)
	}

	stoppedStatus := readLatestShareStatusAfter(t, viewerConn, func() {
		sendPacket(t, adminConn, "share.stop", "req-stop", nil)
		readFrameOfType(t, adminConn, "share.stop_ack")
	})
	if stoppedStatus.Active {
		t.Fatalf("stopped status Active = true, want false (stale room catalog leaked to viewer)")
	}
	if len(stoppedStatus.Files) != 0 {
		t.Fatalf("stopped status Files = %#v, want empty (stale room catalog leaked to viewer)", stoppedStatus.Files)
	}
}

func TestHandleShareStopClearsMirror(t *testing.T) {
	tmpFile, err := os.CreateTemp(t.TempDir(), "share-*.txt")
	if err != nil {
		t.Fatalf("create temp file failed: %v", err)
	}
	if _, err := tmpFile.WriteString("hello"); err != nil {
		t.Fatalf("write temp file failed: %v", err)
	}
	_ = tmpFile.Close()

	env := newWSTestEnv(t)
	server := httptest.NewServer(env.ws)
	defer server.Close()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	adminConn := dialTestWS(t, wsURL, infraws.RoleAdmin, "admin-1")
	defer adminConn.Close()
	readFrameOfType(t, adminConn, "auth_ack")

	viewerConn := dialTestWS(t, wsURL, infraws.RoleViewer, "viewer-1")
	defer viewerConn.Close()
	readFrameOfType(t, viewerConn, "auth_ack")
	readFrameOfType(t, viewerConn, "share.status")

	sendPacket(t, adminConn, "share.start", "req-start", request.StartShareRequest{
		Files: []share.ShareFile{{Path: tmpFile.Name()}},
	})
	readFrameOfType(t, adminConn, "share.start_ack")
	readFrameOfType(t, viewerConn, "share.status")
	drainExtraShareStatus(t, viewerConn)

	env.mirror.Set([]room.SharedEntry{
		{
			ID:           "stale-mirror-file",
			Name:         "stale.txt",
			Size:         1,
			BaseURL:      "http://192.168.1.20:8080",
			DownloadPath: "/api/v1/share/files/stale-mirror-file/download",
		},
	})

	stoppedStatus := readLatestShareStatusAfter(t, viewerConn, func() {
		sendPacket(t, adminConn, "share.stop", "req-stop", nil)
		readFrameOfType(t, adminConn, "share.stop_ack")
	})
	if stoppedStatus.Active {
		t.Fatalf("stopped status Active = true, want false (stale mirror resurfaced after CloseRoom)")
	}
	if len(stoppedStatus.Files) != 0 {
		t.Fatalf("stopped status Files = %#v, want empty (stale mirror resurfaced after CloseRoom)", stoppedStatus.Files)
	}
}

func TestHandleShareStartPeerKeepsMirror(t *testing.T) {
	tmpFile, err := os.CreateTemp(t.TempDir(), "share-*.txt")
	if err != nil {
		t.Fatalf("create temp file failed: %v", err)
	}
	if _, err := tmpFile.WriteString("hello"); err != nil {
		t.Fatalf("write temp file failed: %v", err)
	}
	_ = tmpFile.Close()

	env := newWSTestEnv(t)
	env.mirror.Set([]room.SharedEntry{
		{
			ID:               "peer-a-file",
			Name:             "a.txt",
			Size:             1,
			OwnerDisplayName: "Peer A",
			BaseURL:          "http://192.168.1.20:8080",
			DownloadPath:     "/api/v1/share/files/peer-a-file/download",
		},
		{
			ID:               "peer-b-file",
			Name:             "b.txt",
			Size:             2,
			OwnerDisplayName: "Peer B",
			BaseURL:          "http://192.168.1.30:8080",
			DownloadPath:     "/api/v1/share/files/peer-b-file/download",
		},
	})

	server := httptest.NewServer(env.ws)
	defer server.Close()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	adminConn := dialTestWS(t, wsURL, infraws.RoleAdmin, "admin-1")
	defer adminConn.Close()
	readFrameOfType(t, adminConn, "auth_ack")

	viewerConn := dialTestWS(t, wsURL, infraws.RoleViewer, "viewer-1")
	defer viewerConn.Close()
	readFrameOfType(t, viewerConn, "auth_ack")
	readFrameOfType(t, viewerConn, "share.status")

	sendPacket(t, adminConn, "share.start", "req-start", request.StartShareRequest{
		Files: []share.ShareFile{{Path: tmpFile.Name()}},
	})
	readFrameOfType(t, adminConn, "share.start_ack")

	started := readFrameOfType(t, viewerConn, "share.status")
	var startedStatus share.PublicStatus
	if err := json.Unmarshal(started.Data, &startedStatus); err != nil {
		t.Fatalf("decode started share.status failed: %v", err)
	}
	if len(startedStatus.Files) != 2 {
		t.Fatalf("started status Files = %#v, want 2 (full mirror A+B)", startedStatus.Files)
	}
	ids := map[string]bool{}
	for _, f := range startedStatus.Files {
		ids[f.ID] = true
	}
	if !ids["peer-a-file"] || !ids["peer-b-file"] {
		t.Fatalf("started status Files = %#v, want to include both peer-a-file and peer-b-file from mirror", startedStatus.Files)
	}
	if catalog, _ := env.room.Catalog(); len(catalog) != 0 {
		t.Fatalf("room catalog = %#v, want empty — Peer share must not promote local files into RoomService host", catalog)
	}
}
