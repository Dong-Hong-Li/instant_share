package websocket

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"instant_share/server/internal/config"

	ws "github.com/gorilla/websocket"
)

// AuthFunc 鉴权回调。
type AuthFunc func(ctx context.Context, req AuthRequest) (role, uid string, err error)

// MessageHandler 业务帧处理器。
type MessageHandler func(ctx context.Context, conn *Connection, raw []byte, packet Packet) error

// Client WebSocket 网关：连接升级、会话管理、消息分发。
type Client struct {
	upgrader ws.Upgrader
	manager  *Manager
	cfg      config.WebSocketConfig
	authFunc AuthFunc

	mu       sync.RWMutex
	handlers map[string]MessageHandler

	onConnect       func(role, uid, deviceID string)
	onDisconnect    func(role, uid, deviceID string)
	onViewerConnect func(*Connection)
}

// NewClient 创建 WebSocket 服务。
func NewClient(cfg config.WebSocketConfig) *Client {
	c := &Client{
		manager:  NewManager(),
		cfg:      cfg,
		authFunc: DefaultAuth,
		handlers: make(map[string]MessageHandler),
	}
	c.upgrader = ws.Upgrader{
		ReadBufferSize:  cfg.ReadBufferSize,
		WriteBufferSize: cfg.WriteBufferSize,
		CheckOrigin:     func(*http.Request) bool { return true },
	}
	c.RegisterHandler("ping", handlePing)
	return c
}

// handlePing 处理心跳。
func handlePing(_ context.Context, conn *Connection, _ []byte, packet Packet) error {
	return conn.WriteResponse(Success("pong", packet.RequestID, nil))
}

// SetConnectionHooks 设置连接建立/断开钩子。
func (c *Client) SetConnectionHooks(onConnect, onDisconnect func(role, uid, deviceID string)) {
	c.onConnect = onConnect
	c.onDisconnect = onDisconnect
}

// SetViewerConnectHook 接收者连接鉴权成功后回调（用于推送当前分享状态）。
func (c *Client) SetViewerConnectHook(fn func(*Connection)) {
	c.onViewerConnect = fn
}

// RegisterHandler 注册消息处理器。
func (c *Client) RegisterHandler(packetType string, handler MessageHandler) {
	packetType = strings.TrimSpace(packetType)
	if packetType == "" || handler == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.handlers[packetType] = handler
}

// SetAuthFunc 设置鉴权函数。
func (c *Client) SetAuthFunc(fn AuthFunc) {
	if fn != nil {
		c.authFunc = fn
	}
}

// ServeHTTP 处理 WebSocket 升级。
func (c *Client) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	wsConn, err := c.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[ws] upgrade failed: %v", err)
		return
	}

	conn := newConnection(wsConn, c.cfg.WriteWait())
	defer func() { _ = conn.Close() }()

	authReq, role, uid, err := c.authenticate(r.Context(), conn, r)
	if err != nil {
		_ = conn.WriteResponse(Error("auth_ack", "", CodeUnauthorized, err.Error()))
		return
	}

	conn.SetIdentity(role, uid, authReq.DeviceID)
	c.manager.Add(conn)
	if c.onConnect != nil {
		c.onConnect(role, uid, authReq.DeviceID)
	}
	defer func() {
		c.manager.Remove(conn)
		if c.onDisconnect != nil {
			c.onDisconnect(role, uid, authReq.DeviceID)
		}
	}()

	if err := conn.WriteResponse(Success("auth_ack", "", map[string]any{
		"role":      role,
		"uid":       uid,
		"device_id": authReq.DeviceID,
	})); err != nil {
		log.Printf("[ws] auth ack failed uid=%s: %v", uid, err)
		return
	}

	if role == RoleViewer && c.onViewerConnect != nil {
		c.onViewerConnect(conn)
	}

	log.Printf("[ws] connected role=%s uid=%s device=%s", role, uid, authReq.DeviceID)
	c.readLoop(r.Context(), conn)
}

// GetConnection 获取连接。
func (c *Client) GetConnection(uid, deviceID string) (*Connection, bool) {
	return c.manager.Get(uid, deviceID)
}

// SendToDevice 向指定设备发送消息。
func (c *Client) SendToDevice(uid, deviceID string, packet any) error {
	conn, ok := c.manager.Get(uid, deviceID)
	if !ok {
		return errors.New("websocket connection not found")
	}
	return conn.WriteJSON(packet)
}

// ConnectionCount 返回连接数量。
func (c *Client) ConnectionCount() int {
	return c.manager.Count()
}

// BroadcastToRole 按角色广播消息。
func (c *Client) BroadcastToRole(role string, packet any) {
	c.manager.BroadcastByRole(role, packet)
}

// Close 关闭房间并清空状态。
func (c *Client) Close() error {
	conns := c.allConnections()
	// lastErr。
	var lastErr error
	for _, conn := range conns {
		if err := conn.Close(); err != nil {
			lastErr = err
		}
	}
	return lastErr
}

// allConnections 返回所有连接。
func (c *Client) allConnections() []*Connection {
	c.manager.mu.RLock()
	defer c.manager.mu.RUnlock()

	conns := make([]*Connection, 0, len(c.manager.connections))
	for _, conn := range c.manager.connections {
		conns = append(conns, conn)
	}
	return conns
}

// authenticate 处理连接鉴权。
func (c *Client) authenticate(ctx context.Context, conn *Connection, r *http.Request) (AuthRequest, string, string, error) {
	req := AuthRequest{
		Type:     "auth",
		Role:     strings.TrimSpace(r.URL.Query().Get("role")),
		DeviceID: strings.TrimSpace(r.URL.Query().Get("device_id")),
	}
	if req.Role == "" && req.DeviceID == "" {
		_ = conn.raw().SetReadDeadline(time.Now().Add(c.cfg.AuthTimeout()))
		if err := conn.raw().ReadJSON(&req); err != nil {
			return AuthRequest{}, "", "", errors.New("auth frame required")
		}
	}
	req.Type = strings.TrimSpace(req.Type)
	if req.Type == "" {
		req.Type = "auth"
	}

	role, uid, err := c.authFunc(ctx, req)
	if err != nil {
		return AuthRequest{}, "", "", err
	}
	req.Role = role
	return req, role, uid, nil
}

// readLoop 读取 WS 消息。
func (c *Client) readLoop(ctx context.Context, conn *Connection) {
	conn.raw().SetReadLimit(c.cfg.ReadLimit)
	pongWait := c.cfg.PongWait()
	pingPeriod := (pongWait * 9) / 10
	_ = conn.raw().SetReadDeadline(time.Now().Add(pongWait))

	conn.raw().SetPongHandler(func(string) error {
		conn.UpdateActiveAt()
		return conn.raw().SetReadDeadline(time.Now().Add(pongWait))
	})

	refreshReadDeadline := func() {
		_ = conn.raw().SetReadDeadline(time.Now().Add(pongWait))
	}

	ticker := time.NewTicker(pingPeriod)
	defer ticker.Stop()

	done := make(chan struct{})
	defer close(done)

	go func() {
		writeWait := c.cfg.WriteWait()
		for {
			select {
			case <-ticker.C:
				if err := conn.WritePing(writeWait); err != nil {
					return
				}
			case <-done:
				return
			case <-ctx.Done():
				return
			}
		}
	}()

	for {
		messageType, payload, err := conn.raw().ReadMessage()
		if err != nil {
			if ws.IsUnexpectedCloseError(err, ws.CloseGoingAway, ws.CloseNormalClosure) {
				log.Printf("[ws] read failed uid=%s: %v", conn.UID(), err)
			}
			return
		}
		if messageType != ws.TextMessage && messageType != ws.BinaryMessage {
			continue
		}
		if messageType == ws.BinaryMessage {
			continue
		}

		conn.UpdateActiveAt()
		refreshReadDeadline()
		c.dispatch(ctx, conn, payload)
	}
}

// dispatch 分发 WS 消息。
func (c *Client) dispatch(ctx context.Context, conn *Connection, payload []byte) {
	// packet。
	var packet Packet
	if err := json.Unmarshal(payload, &packet); err != nil {
		_ = conn.WriteResponse(Error("error", "", CodeBadRequest, "invalid json"))
		return
	}

	c.mu.RLock()
	handler := c.handlers[packet.Type]
	c.mu.RUnlock()
	if handler == nil {
		_ = conn.WriteResponse(Error("error", packet.RequestID, CodeBadRequest, "unsupported message type"))
		return
	}
	if err := handler(ctx, conn, payload, packet); err != nil {
		log.Printf("[ws] handler failed type=%s uid=%s: %v", packet.Type, conn.UID(), err)
		_ = conn.WriteResponse(Error("error", packet.RequestID, CodeInternal, err.Error()))
	}
}

// DefaultAuth 默认鉴权：admin 控制分享，viewer 订阅分享状态，peer 申请加入房间。
func DefaultAuth(_ context.Context, req AuthRequest) (string, string, error) {
	role := strings.TrimSpace(req.Role)
	deviceID := strings.TrimSpace(req.DeviceID)

	if deviceID == "" {
		return "", "", errors.New("device_id required")
	}

	switch role {
	case RoleAdmin:
		return role, RoleAdmin, nil
	case RoleViewer:
		return role, deviceID, nil
	case RolePeer:
		return role, deviceID, nil
	default:
		return "", "", errors.New("role must be admin, viewer, or peer")
	}
}
