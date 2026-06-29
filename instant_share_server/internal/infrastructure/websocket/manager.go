package websocket

import "sync"

// Manager 管理在线 WebSocket 连接。
type Manager struct {
	mu          sync.RWMutex
	connections map[string]*Connection
}

func NewManager() *Manager {
	return &Manager{
		connections: make(map[string]*Connection),
	}
}

func (m *Manager) Add(conn *Connection) {
	m.mu.Lock()
	defer m.mu.Unlock()

	key := conn.UID()
	if old := m.connections[key]; old != nil && old != conn {
		_ = old.Close()
	}
	m.connections[key] = conn
}

func (m *Manager) Remove(conn *Connection) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.connections[conn.UID()] == conn {
		delete(m.connections, conn.UID())
	}
}

func (m *Manager) Get(uid, _ string) (*Connection, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	conn, ok := m.connections[uid]
	return conn, ok
}

func (m *Manager) List(uid string) []*Connection {
	m.mu.RLock()
	defer m.mu.RUnlock()

	conn, ok := m.connections[uid]
	if !ok {
		return nil
	}
	return []*Connection{conn}
}

func (m *Manager) Count() int {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return len(m.connections)
}

func (m *Manager) OnlineUserCount() int {
	return m.Count()
}

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
