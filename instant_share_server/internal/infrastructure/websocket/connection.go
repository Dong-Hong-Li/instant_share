package websocket

import (
	"sync"
	"time"

	gws "github.com/gorilla/websocket"
)

// Connection 一条 WebSocket 长连接。
type Connection struct {
	role     string
	uid      string
	deviceID string
	conn     *gws.Conn
	writeWait time.Duration
	writeMu  sync.Mutex
	createdAt time.Time
	activeAt time.Time
}

func newConnection(conn *gws.Conn, writeWait time.Duration) *Connection {
	now := time.Now()
	return &Connection{
		conn:      conn,
		writeWait: writeWait,
		createdAt: now,
		activeAt:  now,
	}
}

func (c *Connection) SetIdentity(role, uid, deviceID string) {
	c.role = role
	c.uid = uid
	c.deviceID = deviceID
}

func (c *Connection) Role() string {
	return c.role
}

func (c *Connection) UID() string {
	return c.uid
}

func (c *Connection) DeviceID() string {
	return c.deviceID
}

func (c *Connection) CreatedAt() time.Time {
	return c.createdAt
}

func (c *Connection) ActiveAt() time.Time {
	return c.activeAt
}

func (c *Connection) UpdateActiveAt() {
	c.activeAt = time.Now()
}

func (c *Connection) raw() *gws.Conn {
	return c.conn
}

func (c *Connection) WriteJSON(v any) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_ = c.conn.SetWriteDeadline(time.Now().Add(c.writeWait))
	return c.conn.WriteJSON(v)
}

func (c *Connection) WritePacket(packet Packet) error {
	return c.WriteJSON(packet)
}

func (c *Connection) WriteResponse(resp Response) error {
	return c.WriteJSON(resp)
}

func (c *Connection) WriteBinary(payload []byte) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_ = c.conn.SetWriteDeadline(time.Now().Add(c.writeWait))
	return c.conn.WriteMessage(gws.BinaryMessage, payload)
}

func (c *Connection) Close() error {
	return c.conn.Close()
}
