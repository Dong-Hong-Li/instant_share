package websocket

import (
	"sync"
	"time"

	gws "github.com/gorilla/websocket"
)

// Connection 一条 WebSocket 长连接。
type Connection struct {
	role      string
	uid       string
	deviceID  string
	conn      *gws.Conn
	writeWait time.Duration
	writeMu   sync.Mutex
	createdAt time.Time
	activeAt  time.Time
}

// newConnection。
func newConnection(conn *gws.Conn, writeWait time.Duration) *Connection {
	now := time.Now()
	return &Connection{
		conn:      conn,
		writeWait: writeWait,
		createdAt: now,
		activeAt:  now,
	}
}

// SetIdentity。
func (c *Connection) SetIdentity(role, uid, deviceID string) {
	c.role = role
	c.uid = uid
	c.deviceID = deviceID
}

// Role。
func (c *Connection) Role() string {
	return c.role
}

// UID。
func (c *Connection) UID() string {
	return c.uid
}

// DeviceID。
func (c *Connection) DeviceID() string {
	return c.deviceID
}

// CreatedAt。
func (c *Connection) CreatedAt() time.Time {
	return c.createdAt
}

// ActiveAt。
func (c *Connection) ActiveAt() time.Time {
	return c.activeAt
}

// UpdateActiveAt。
func (c *Connection) UpdateActiveAt() {
	c.activeAt = time.Now()
}

// raw。
func (c *Connection) raw() *gws.Conn {
	return c.conn
}

// WriteJSON。
func (c *Connection) WriteJSON(v any) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_ = c.conn.SetWriteDeadline(time.Now().Add(c.writeWait))
	return c.conn.WriteJSON(v)
}

// WritePacket。
func (c *Connection) WritePacket(packet Packet) error {
	return c.WriteJSON(packet)
}

// WriteResponse。
func (c *Connection) WriteResponse(resp Response) error {
	return c.WriteJSON(resp)
}

// WriteBinary。
func (c *Connection) WriteBinary(payload []byte) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_ = c.conn.SetWriteDeadline(time.Now().Add(c.writeWait))
	return c.conn.WriteMessage(gws.BinaryMessage, payload)
}

// WritePing。
func (c *Connection) WritePing(writeWait time.Duration) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	return c.conn.WriteControl(gws.PingMessage, nil, time.Now().Add(writeWait))
}

// Close 关闭房间并清空状态。
func (c *Connection) Close() error {
	return c.conn.Close()
}
