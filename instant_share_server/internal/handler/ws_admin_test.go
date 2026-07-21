package handler

import (
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	gws "github.com/gorilla/websocket"

	"instant_share/server/internal/config"
	"instant_share/server/internal/infrastructure/websocket"
	"instant_share/server/internal/model"
	"instant_share/server/internal/service"
)

// wsTestFrame 与 websocket.Response 结构一致，但 Data 保留为原始 JSON 以便按需解码。
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

// readFrameOfType 跳过不相关帧（如其它角色也会收到的 room.notify），
// 直到读到目标类型或超时，用于避免测试对广播顺序过度敏感。
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

func sendPacket(t *testing.T, conn *gws.Conn, packetType, requestID string, data any) {
	t.Helper()
	raw, err := json.Marshal(data)
	if err != nil {
		t.Fatalf("marshal packet data failed: %v", err)
	}
	packet := websocket.Packet{Type: packetType, RequestID: requestID, Data: raw}
	if data == nil {
		packet.Data = nil
	}
	if err := conn.WriteJSON(packet); err != nil {
		t.Fatalf("write packet %q failed: %v", packetType, err)
	}
}

// TestHandleShareStopBroadcastsAfterRoomClose 覆盖 P1：share.stop 必须先关闭房间（清空
// RoomService 目录），再广播 share.status，避免 viewer 收到「已停止分享但仍带旧房间文件、
// active=true」的过期状态。
func TestHandleShareStopBroadcastsAfterRoomClose(t *testing.T) {
	tmpFile, err := os.CreateTemp(t.TempDir(), "share-*.txt")
	if err != nil {
		t.Fatalf("create temp file failed: %v", err)
	}
	if _, err := tmpFile.WriteString("hello"); err != nil {
		t.Fatalf("write temp file failed: %v", err)
	}
	_ = tmpFile.Close()

	share := service.NewShareService("127.0.0.1", 0)
	room := service.NewRoomService()
	mirror := service.NewPublicRoomCatalog()
	wsClient := websocket.NewClient(config.DefaultWebSocketConfig())
	wsRoom := NewWSRoomHandler(room, wsClient)
	admin := NewWSAdminHandler(share, wsClient, wsRoom, room, mirror)
	admin.Register(wsClient)

	server := httptest.NewServer(wsClient)
	defer server.Close()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	adminConn := dialTestWS(t, wsURL, websocket.RoleAdmin, "admin-1")
	defer adminConn.Close()
	readFrameOfType(t, adminConn, "auth_ack")

	viewerConn := dialTestWS(t, wsURL, websocket.RoleViewer, "viewer-1")
	defer viewerConn.Close()
	readFrameOfType(t, viewerConn, "auth_ack")

	initial := readFrameOfType(t, viewerConn, "share.status")
	var initialStatus model.PublicShareStatus
	if err := json.Unmarshal(initial.Data, &initialStatus); err != nil {
		t.Fatalf("decode initial share.status failed: %v", err)
	}
	if initialStatus.Active {
		t.Fatalf("initial status Active = true, want false before any share starts")
	}

	sendPacket(t, adminConn, "share.start", "req-start", model.StartShareRequest{
		Files: []model.ShareFile{{Path: tmpFile.Name()}},
	})
	readFrameOfType(t, adminConn, "share.start_ack")

	started := readFrameOfType(t, viewerConn, "share.status")
	var startedStatus model.PublicShareStatus
	if err := json.Unmarshal(started.Data, &startedStatus); err != nil {
		t.Fatalf("decode started share.status failed: %v", err)
	}
	if !startedStatus.Active || len(startedStatus.Files) != 1 {
		t.Fatalf("started status = %#v, want Active=true with 1 file", startedStatus)
	}

	sendPacket(t, adminConn, "share.stop", "req-stop", nil)
	readFrameOfType(t, adminConn, "share.stop_ack")

	stopped := readFrameOfType(t, viewerConn, "share.status")
	var stoppedStatus model.PublicShareStatus
	if err := json.Unmarshal(stopped.Data, &stoppedStatus); err != nil {
		t.Fatalf("decode stopped share.status failed: %v", err)
	}
	if stoppedStatus.Active {
		t.Fatalf("stopped status Active = true, want false (stale room catalog leaked to viewer)")
	}
	if len(stoppedStatus.Files) != 0 {
		t.Fatalf("stopped status Files = %#v, want empty (stale room catalog leaked to viewer)", stoppedStatus.Files)
	}
}

// TestHandleShareStopClearsMirror 覆盖 P1 补充发现：CloseRoom 会清空 RoomService.HostBaseURL，
// 使 isRoomHost 变为 false；若不在 share.stop 时同时清空 Peer 镜像，残留的旧镜像会在
// CloseRoom 之后抢先顶替空房间目录，让 viewer 收到过期的 active=true 状态。
func TestHandleShareStopClearsMirror(t *testing.T) {
	tmpFile, err := os.CreateTemp(t.TempDir(), "share-*.txt")
	if err != nil {
		t.Fatalf("create temp file failed: %v", err)
	}
	if _, err := tmpFile.WriteString("hello"); err != nil {
		t.Fatalf("write temp file failed: %v", err)
	}
	_ = tmpFile.Close()

	share := service.NewShareService("127.0.0.1", 0)
	room := service.NewRoomService()
	mirror := service.NewPublicRoomCatalog()
	wsClient := websocket.NewClient(config.DefaultWebSocketConfig())
	wsRoom := NewWSRoomHandler(room, wsClient)
	admin := NewWSAdminHandler(share, wsClient, wsRoom, room, mirror)
	admin.Register(wsClient)

	server := httptest.NewServer(wsClient)
	defer server.Close()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	adminConn := dialTestWS(t, wsURL, websocket.RoleAdmin, "admin-1")
	defer adminConn.Close()
	readFrameOfType(t, adminConn, "auth_ack")

	viewerConn := dialTestWS(t, wsURL, websocket.RoleViewer, "viewer-1")
	defer viewerConn.Close()
	readFrameOfType(t, viewerConn, "auth_ack")
	readFrameOfType(t, viewerConn, "share.status") // 初始状态，忽略。

	sendPacket(t, adminConn, "share.start", "req-start", model.StartShareRequest{
		Files: []model.ShareFile{{Path: tmpFile.Name()}},
	})
	readFrameOfType(t, adminConn, "share.start_ack")
	readFrameOfType(t, viewerConn, "share.status") // 分享启动状态，忽略。

	// 模拟本机此前作为 Peer 时残留的镜像目录（例如收到过 room.public_catalog.sync）。
	// 分享进行中 isRoomHost=true，该镜像本应被忽略；停止分享后 isRoomHost 变为 false，
	// 正是 P1 描述的「旧镜像重新浮现」窗口。
	mirror.Set([]model.SharedEntry{
		{
			ID:           "stale-mirror-file",
			Name:         "stale.txt",
			Size:         1,
			BaseURL:      "http://192.168.1.20:8080",
			DownloadPath: "/api/v1/share/files/stale-mirror-file/download",
		},
	})

	sendPacket(t, adminConn, "share.stop", "req-stop", nil)
	readFrameOfType(t, adminConn, "share.stop_ack")

	stopped := readFrameOfType(t, viewerConn, "share.status")
	var stoppedStatus model.PublicShareStatus
	if err := json.Unmarshal(stopped.Data, &stoppedStatus); err != nil {
		t.Fatalf("decode stopped share.status failed: %v", err)
	}
	if stoppedStatus.Active {
		t.Fatalf("stopped status Active = true, want false (stale mirror resurfaced after CloseRoom)")
	}
	if len(stoppedStatus.Files) != 0 {
		t.Fatalf("stopped status Files = %#v, want empty (stale mirror resurfaced after CloseRoom)", stoppedStatus.Files)
	}
}

// TestHandleShareStartPeerKeepsMirror 覆盖 Critical 修复：Peer B 已作为 Peer 聚合到一份完整的
// 跨设备镜像目录（A+B），当它自己开始本地分享时，share.start 触发的 SyncHostCatalog 不得把
// 本机晋升为 RoomService 的 "host"（镜像非空则早退），且不得清空镜像。因此 B 的 /share 仍应
// 展示完整的 A+B，而不是退化为只剩 B。
func TestHandleShareStartPeerKeepsMirror(t *testing.T) {
	tmpFile, err := os.CreateTemp(t.TempDir(), "share-*.txt")
	if err != nil {
		t.Fatalf("create temp file failed: %v", err)
	}
	if _, err := tmpFile.WriteString("hello"); err != nil {
		t.Fatalf("write temp file failed: %v", err)
	}
	_ = tmpFile.Close()

	share := service.NewShareService("127.0.0.1", 0)
	room := service.NewRoomService()
	mirror := service.NewPublicRoomCatalog()
	// 预先播种本机作为 Peer 聚合到的完整跨设备目录：A（远端）+ B（本机）。
	mirror.Set([]model.SharedEntry{
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
	wsClient := websocket.NewClient(config.DefaultWebSocketConfig())
	wsRoom := NewWSRoomHandler(room, wsClient)
	wsRoom.SetPublicMirror(mirror) // 与生产接线一致：SyncHostCatalog 才能感知镜像并早退。
	admin := NewWSAdminHandler(share, wsClient, wsRoom, room, mirror)
	admin.Register(wsClient)

	server := httptest.NewServer(wsClient)
	defer server.Close()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	adminConn := dialTestWS(t, wsURL, websocket.RoleAdmin, "admin-1")
	defer adminConn.Close()
	readFrameOfType(t, adminConn, "auth_ack")

	viewerConn := dialTestWS(t, wsURL, websocket.RoleViewer, "viewer-1")
	defer viewerConn.Close()
	readFrameOfType(t, viewerConn, "auth_ack")
	readFrameOfType(t, viewerConn, "share.status") // 初始状态，忽略。

	sendPacket(t, adminConn, "share.start", "req-start", model.StartShareRequest{
		Files: []model.ShareFile{{Path: tmpFile.Name()}},
	})
	readFrameOfType(t, adminConn, "share.start_ack")

	started := readFrameOfType(t, viewerConn, "share.status")
	var startedStatus model.PublicShareStatus
	if err := json.Unmarshal(started.Data, &startedStatus); err != nil {
		t.Fatalf("decode started share.status failed: %v", err)
	}
	if len(startedStatus.Files) != 2 {
		t.Fatalf("started status Files = %#v, want 2 (full mirror A+B), Peer local share must not shrink /share to only B", startedStatus.Files)
	}
	ids := map[string]bool{}
	for _, f := range startedStatus.Files {
		ids[f.ID] = true
	}
	if !ids["peer-a-file"] || !ids["peer-b-file"] {
		t.Fatalf("started status Files = %#v, want to include both peer-a-file and peer-b-file from mirror", startedStatus.Files)
	}
	// 房间目录不应被本机 Peer 分享污染（SyncHostCatalog 早退，未写入 "host"）。
	if catalog, _ := room.Catalog(); len(catalog) != 0 {
		t.Fatalf("room catalog = %#v, want empty — Peer share must not promote local files into RoomService host", catalog)
	}
}
