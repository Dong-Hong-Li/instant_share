// Package service 实现互享房间用例：配对、成员、聚合目录与跨域通知钩子。
package service

import (
	"sort"
	"strings"
	"sync"
	"time"

	"instant_share/server/internal/application/room/repository"
	"instant_share/server/internal/domain/room"
)

// ownerCatalog 单个设备在房间内维护的共享文件集合。
type ownerCatalog struct {
	// displayName 设备展示名。
	displayName string
	// baseURL 该设备 HTTP 根，供跨设备直连下载。
	baseURL string
	// files 该设备发布的文件元数据。
	files []room.SharedFileMeta
}

// Service 互传房间用例（内存状态机）。
//
// 状态变更后通过 SetHooks 通知 interfaces 层广播；本包不直接依赖 WebSocket。
type Service struct {
	mu sync.RWMutex

	// active 房间是否已 EnsureRoom。
	active bool
	// hostDeviceID Host 设备 ID（通常为 "host"）。
	hostDeviceID string
	// hostBaseURL Host HTTP 根（不含 /share）。
	hostBaseURL string
	// sessionID 房间/会话 ID（对外 room_id）。
	sessionID string
	// revision 聚合目录版本号，每次目录变更递增。
	revision int
	// pending 待审批配对请求，key=deviceID。
	pending map[string]room.PendingRequest
	// members 已入房成员，key=deviceID。
	members map[string]room.Member
	// ownerCatalogs 各设备发布的文件，聚合为 Catalog()。
	ownerCatalogs map[string]ownerCatalog
	// now 当前时间；测试可 SetNow 注入。
	now func() time.Time

	// onCatalogUpdated 目录变更回调（bootstrap 注入）。
	onCatalogUpdated repository.CatalogUpdatedHook
	// onPendingUpdated pending 变更回调。
	onPendingUpdated repository.PendingUpdatedHook
}

/**
 * @description: NewService 创建空房间用例（需 EnsureRoom 后才能配对）。
 * @return {*Service}
 */
func NewService() *Service {
	return &Service{
		pending:       make(map[string]room.PendingRequest),
		members:       make(map[string]room.Member),
		ownerCatalogs: make(map[string]ownerCatalog),
		now:           time.Now,
	}
}

/**
 * @description: SetHooks 注册跨域通知回调（由 bootstrap 装配，解耦 interfaces）。
 * @param {CatalogUpdatedHook} onCatalog 目录变更
 * @param {PendingUpdatedHook} onPending 待审批列表变更
 */
func (s *Service) SetHooks(onCatalog repository.CatalogUpdatedHook, onPending repository.PendingUpdatedHook) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.onCatalogUpdated = onCatalog
	s.onPendingUpdated = onPending
}

// SetNow 测试注入时钟。
func (s *Service) SetNow(now func() time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if now == nil {
		s.now = time.Now
		return
	}
	s.now = now
}

func (s *Service) fireCatalogUpdated() {
	if s.onCatalogUpdated != nil {
		s.onCatalogUpdated()
	}
}

func (s *Service) firePendingUpdated() {
	if s.onPendingUpdated != nil {
		s.onPendingUpdated()
	}
}

/**
 * @description: EnsureRoom 打开/刷新房间，使 Peer 可提交配对。
 * @param {string} hostDeviceID Host 设备 ID
 * @param {string} hostBaseURL Host HTTP 根
 * @param {string} sessionID 会话/房间 ID
 */
func (s *Service) EnsureRoom(hostDeviceID, hostBaseURL, sessionID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.active = true
	s.hostDeviceID = strings.TrimSpace(hostDeviceID)
	s.hostBaseURL = strings.TrimRight(strings.TrimSpace(hostBaseURL), "/")
	s.sessionID = strings.TrimSpace(sessionID)
	if s.pending == nil {
		s.pending = make(map[string]room.PendingRequest)
	}
	if s.members == nil {
		s.members = make(map[string]room.Member)
	}
	if s.ownerCatalogs == nil {
		s.ownerCatalogs = make(map[string]ownerCatalog)
	}
}

/**
 * @description: RequestPairing Peer 提交配对；同 deviceID 重复提交会刷新展示名/URL/过期时间，保留首次 RequestedAt。
 * @return {room.PendingRequest, error} 房间未开启返回 ErrRoomNotActive
 */
func (s *Service) RequestPairing(deviceID, displayName, peerBaseURL string) (room.PendingRequest, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if !s.active {
		return room.PendingRequest{}, room.ErrRoomNotActive
	}
	deviceID = strings.TrimSpace(deviceID)
	displayName = strings.TrimSpace(displayName)
	peerBaseURL = strings.TrimRight(strings.TrimSpace(peerBaseURL), "/")
	if deviceID == "" || peerBaseURL == "" {
		return room.PendingRequest{}, room.ErrInvalidRoomArgument
	}
	if displayName == "" {
		displayName = deviceID
	}

	now := s.now()
	req := room.PendingRequest{
		DeviceID:    deviceID,
		DisplayName: displayName,
		PeerBaseURL: peerBaseURL,
		RequestedAt: now,
		ExpiresAt:   now.Add(room.PairingTTL),
	}
	if existing, ok := s.pending[deviceID]; ok {
		req.RequestedAt = existing.RequestedAt
	}
	s.pending[deviceID] = req
	return req, nil
}

/**
 * @description: Approve Host 通过配对；成功后设备进入 members，可发 share.offer。
 */
func (s *Service) Approve(deviceID string) (room.Member, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	deviceID = strings.TrimSpace(deviceID)
	req, ok := s.pending[deviceID]
	if !ok {
		return room.Member{}, room.ErrPairingNotFound
	}
	if s.now().After(req.ExpiresAt) {
		delete(s.pending, deviceID)
		return room.Member{}, room.ErrPairingExpired
	}
	member := room.Member{
		DeviceID:    req.DeviceID,
		DisplayName: req.DisplayName,
		PeerBaseURL: req.PeerBaseURL,
	}
	s.members[deviceID] = member
	delete(s.pending, deviceID)
	return member, nil
}

// Reject 拒绝指定设备的配对请求。
func (s *Service) Reject(deviceID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	deviceID = strings.TrimSpace(deviceID)
	if _, ok := s.pending[deviceID]; !ok {
		return room.ErrPairingNotFound
	}
	delete(s.pending, deviceID)
	return nil
}

/**
 * @description: RemoveMember 移除成员并清理其目录（Peer 主动 room.leave 或 Host 踢人）。
 * @return {catalog, revision, removed} removed=false 表示设备本就不在房间且无目录
 */
func (s *Service) RemoveMember(deviceID string) ([]room.SharedEntry, int, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	deviceID = strings.TrimSpace(deviceID)
	if deviceID == "" {
		return s.catalogLocked(), s.revision, false
	}
	_, existed := s.members[deviceID]
	if !existed {
		if _, hasCatalog := s.ownerCatalogs[deviceID]; !hasCatalog {
			return s.catalogLocked(), s.revision, false
		}
	}
	delete(s.members, deviceID)
	delete(s.ownerCatalogs, deviceID)
	s.revision++
	return s.catalogLocked(), s.revision, true
}

// SweepExpired 清理过期配对请求。
func (s *Service) SweepExpired() []string {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := s.now()
	expired := make([]string, 0)
	for deviceID, req := range s.pending {
		if now.After(req.ExpiresAt) {
			expired = append(expired, deviceID)
			delete(s.pending, deviceID)
		}
	}
	sort.Strings(expired)
	return expired
}

/**
 * @description: SetOwnerFiles 更新某设备发布的文件分片，并返回最新聚合目录与 revision。
 */
func (s *Service) SetOwnerFiles(ownerID, displayName, baseURL string, files []room.SharedFileMeta) ([]room.SharedEntry, int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	ownerID = strings.TrimSpace(ownerID)
	displayName = strings.TrimSpace(displayName)
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if ownerID == "" {
		return s.catalogLocked(), s.revision
	}
	cloned := make([]room.SharedFileMeta, len(files))
	copy(cloned, files)
	s.ownerCatalogs[ownerID] = ownerCatalog{
		displayName: displayName,
		baseURL:     baseURL,
		files:       cloned,
	}
	s.revision++
	return s.catalogLocked(), s.revision
}

// Catalog 返回当前共享目录和版本号。
func (s *Service) Catalog() ([]room.SharedEntry, int) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.catalogLocked(), s.revision
}

// Members 返回已加入房间的成员列表。
func (s *Service) Members() []room.Member {
	s.mu.RLock()
	defer s.mu.RUnlock()

	members := make([]room.Member, 0, len(s.members))
	for _, member := range s.members {
		members = append(members, member)
	}
	sort.Slice(members, func(i, j int) bool {
		return members[i].DeviceID < members[j].DeviceID
	})
	return members
}

// Pending 返回待处理配对请求列表。
func (s *Service) Pending() []room.PendingRequest {
	s.mu.RLock()
	defer s.mu.RUnlock()

	pending := make([]room.PendingRequest, 0, len(s.pending))
	for _, req := range s.pending {
		pending = append(pending, req)
	}
	sort.Slice(pending, func(i, j int) bool {
		return pending[i].RequestedAt.Before(pending[j].RequestedAt)
	})
	return pending
}

// Close 关闭房间并清空状态。
func (s *Service) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.active = false
	s.hostDeviceID = ""
	s.hostBaseURL = ""
	s.sessionID = ""
	s.revision = 0
	s.pending = make(map[string]room.PendingRequest)
	s.members = make(map[string]room.Member)
	s.ownerCatalogs = make(map[string]ownerCatalog)
}

// IsAuthorizedPeer 判断设备是否已加入房间。
func (s *Service) IsAuthorizedPeer(deviceID string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, ok := s.members[strings.TrimSpace(deviceID)]
	return ok
}

// HostBaseURL 返回主机基础地址。
func (s *Service) HostBaseURL() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.hostBaseURL
}

// HostDeviceID 返回主机设备 ID。
func (s *Service) HostDeviceID() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.hostDeviceID
}

// Member 查询成员。
func (s *Service) Member(deviceID string) (room.Member, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	member, ok := s.members[strings.TrimSpace(deviceID)]
	return member, ok
}

// RoomID 返回房间 ID。
func (s *Service) RoomID() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.sessionID
}

// catalogLocked 在已持锁前提下按 ownerID 排序聚合全部 SharedEntry。
func (s *Service) catalogLocked() []room.SharedEntry {
	owners := make([]string, 0, len(s.ownerCatalogs))
	for ownerID := range s.ownerCatalogs {
		owners = append(owners, ownerID)
	}
	sort.Strings(owners)

	entries := make([]room.SharedEntry, 0)
	for _, ownerID := range owners {
		catalog := s.ownerCatalogs[ownerID]
		for _, file := range catalog.files {
			entries = append(entries, room.SharedEntry{
				ID:               file.ID,
				Name:             file.Name,
				Size:             file.Size,
				OwnerID:          ownerID,
				OwnerDisplayName: catalog.displayName,
				BaseURL:          catalog.baseURL,
				DownloadPath:     file.DownloadPath,
			})
		}
	}
	return entries
}

/**
 * @description: NotifyCatalogUpdated 由 interfaces 在目录业务完成后显式触发 hooks
 *（例如 SyncHostCatalog 写入后）；hooks 内通常广播 room.notify + share.status。
 */
func (s *Service) NotifyCatalogUpdated() { s.fireCatalogUpdated() }

/**
 * @description: NotifyPendingUpdated 由 interfaces 在 pending 变化后触发（审批/超时/关房）。
 */
func (s *Service) NotifyPendingUpdated() { s.firePendingUpdated() }
