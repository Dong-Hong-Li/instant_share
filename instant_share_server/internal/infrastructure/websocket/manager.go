package websocket

import "sync"

// Manager 管理在线 WebSocket 连接。
type Manager struct {
	mu          sync.RWMutex
	connections map[string]*Connection
}

// NewManager 创建连接管理器。
func NewManager() *Manager {
	return &Manager{
		connections: make(map[string]*Connection),
	}
}

// Add 添加连接。
func (m *Manager) Add(conn *Connection) {
	m.mu.Lock()
	defer m.mu.Unlock()

	key := conn.UID()
	if old := m.connections[key]; old != nil && old != conn {
		_ = old.Close()
	}
	m.connections[key] = conn
}

// Remove 移除连接。
func (m *Manager) Remove(conn *Connection) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.connections[conn.UID()] == conn {
		delete(m.connections, conn.UID())
	}
}

// Get 获取连接。
func (m *Manager) Get(uid, _ string) (*Connection, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	conn, ok := m.connections[uid]
	return conn, ok
}

// List 返回连接列表。
func (m *Manager) List(uid string) []*Connection {
	m.mu.RLock()
	defer m.mu.RUnlock()

	conn, ok := m.connections[uid]
	if !ok {
		return nil
	}
	return []*Connection{conn}
}

// Count 返回连接数量。
func (m *Manager) Count() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.connections)
}

// OnlineUserCount 返回在线用户数量。
func (m *Manager) OnlineUserCount() int {
	return m.Count()
}

// BroadcastByRole 按角色广播消息。
func (m *Manager) BroadcastByRole(role string, packet any) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, conn := range m.connections {
		if conn.Role() != role {
			continue
		}
		_ = conn.WriteJSON(packet)
	}
}
