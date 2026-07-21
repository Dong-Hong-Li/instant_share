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
