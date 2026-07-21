package service

import (
	"errors"
	"sort"
	"strings"
	"sync"
	"time"

	"instant_share/server/internal/model"
)

// roomPairingTTL 配对请求有效期。
const roomPairingTTL = 60 * time.Second

var (
	// ErrRoomNotActive 房间未开启错误。
	ErrRoomNotActive = errors.New("room is not active")
	// ErrPairingNotFound 配对请求不存在错误。
	ErrPairingNotFound = errors.New("pairing request not found")
	// ErrPairingExpired 配对请求已过期错误。
	ErrPairingExpired = errors.New("pairing request expired")
	// ErrInvalidRoomArgument 房间参数无效错误。
	ErrInvalidRoomArgument = errors.New("invalid room argument")
)

// ownerCatalog 单个设备维护的共享目录。
type ownerCatalog struct {
	displayName string
	baseURL     string
	files       []model.SharedFileMeta
}

// RoomService 互传房间服务。
type RoomService struct {
	mu sync.RWMutex

	active        bool
	hostDeviceID  string
	hostBaseURL   string
	sessionID     string
	revision      int
	pending       map[string]model.PendingRequest
	members       map[string]model.Member
	ownerCatalogs map[string]ownerCatalog
	now           func() time.Time
}

// NewRoomService 创建互传房间服务。
func NewRoomService() *RoomService {
	return &RoomService{
		pending:       make(map[string]model.PendingRequest),
		members:       make(map[string]model.Member),
		ownerCatalogs: make(map[string]ownerCatalog),
		now:           time.Now,
	}
}

// EnsureRoom 确保房间处于可配对状态。
func (s *RoomService) EnsureRoom(hostDeviceID, hostBaseURL, sessionID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.active = true
	s.hostDeviceID = strings.TrimSpace(hostDeviceID)
	s.hostBaseURL = strings.TrimRight(strings.TrimSpace(hostBaseURL), "/")
	s.sessionID = strings.TrimSpace(sessionID)
	if s.pending == nil {
		s.pending = make(map[string]model.PendingRequest)
	}
	if s.members == nil {
		s.members = make(map[string]model.Member)
	}
	if s.ownerCatalogs == nil {
		s.ownerCatalogs = make(map[string]ownerCatalog)
	}
}

// RequestPairing 提交配对请求。
func (s *RoomService) RequestPairing(deviceID, displayName, peerBaseURL string) (model.PendingRequest, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if !s.active {
		return model.PendingRequest{}, ErrRoomNotActive
	}
	deviceID = strings.TrimSpace(deviceID)
	displayName = strings.TrimSpace(displayName)
	peerBaseURL = strings.TrimRight(strings.TrimSpace(peerBaseURL), "/")
	if deviceID == "" || peerBaseURL == "" {
		return model.PendingRequest{}, ErrInvalidRoomArgument
	}
	if displayName == "" {
		displayName = deviceID
	}

	now := s.now()
	req := model.PendingRequest{
		DeviceID:    deviceID,
		DisplayName: displayName,
		PeerBaseURL: peerBaseURL,
		RequestedAt: now,
		ExpiresAt:   now.Add(roomPairingTTL),
	}
	if existing, ok := s.pending[deviceID]; ok {
		req.RequestedAt = existing.RequestedAt
	}
	s.pending[deviceID] = req
	return req, nil
}

// Approve 通过指定设备的配对请求。
func (s *RoomService) Approve(deviceID string) (model.Member, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	deviceID = strings.TrimSpace(deviceID)
	req, ok := s.pending[deviceID]
	if !ok {
		return model.Member{}, ErrPairingNotFound
	}
	if s.now().After(req.ExpiresAt) {
		delete(s.pending, deviceID)
		return model.Member{}, ErrPairingExpired
	}
	member := model.Member{
		DeviceID:    req.DeviceID,
		DisplayName: req.DisplayName,
		PeerBaseURL: req.PeerBaseURL,
	}
	s.members[deviceID] = member
	delete(s.pending, deviceID)
	return member, nil
}

// Reject 拒绝指定设备的配对请求。
func (s *RoomService) Reject(deviceID string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	deviceID = strings.TrimSpace(deviceID)
	if _, ok := s.pending[deviceID]; !ok {
		return ErrPairingNotFound
	}
	delete(s.pending, deviceID)
	return nil
}

// RemoveMember 移除已入房成员，并清理其共享目录（主动离房）。
func (s *RoomService) RemoveMember(deviceID string) ([]model.SharedEntry, int, bool) {
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
func (s *RoomService) SweepExpired() []string {
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

// SetOwnerFiles 更新指定设备的共享文件目录。
func (s *RoomService) SetOwnerFiles(ownerID, displayName, baseURL string, files []model.SharedFileMeta) ([]model.SharedEntry, int) {
	s.mu.Lock()
	defer s.mu.Unlock()

	ownerID = strings.TrimSpace(ownerID)
	displayName = strings.TrimSpace(displayName)
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if ownerID == "" {
		return s.catalogLocked(), s.revision
	}
	cloned := make([]model.SharedFileMeta, len(files))
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
func (s *RoomService) Catalog() ([]model.SharedEntry, int) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.catalogLocked(), s.revision
}

// Members 返回已加入房间的成员列表。
func (s *RoomService) Members() []model.Member {
	s.mu.RLock()
	defer s.mu.RUnlock()

	members := make([]model.Member, 0, len(s.members))
	for _, member := range s.members {
		members = append(members, member)
	}
	sort.Slice(members, func(i, j int) bool {
		return members[i].DeviceID < members[j].DeviceID
	})
	return members
}

// Pending 返回待处理配对请求列表。
func (s *RoomService) Pending() []model.PendingRequest {
	s.mu.RLock()
	defer s.mu.RUnlock()

	pending := make([]model.PendingRequest, 0, len(s.pending))
	for _, req := range s.pending {
		pending = append(pending, req)
	}
	sort.Slice(pending, func(i, j int) bool {
		return pending[i].RequestedAt.Before(pending[j].RequestedAt)
	})
	return pending
}

// Close 关闭房间并清空状态。
func (s *RoomService) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.active = false
	s.hostDeviceID = ""
	s.hostBaseURL = ""
	s.sessionID = ""
	s.revision = 0
	s.pending = make(map[string]model.PendingRequest)
	s.members = make(map[string]model.Member)
	s.ownerCatalogs = make(map[string]ownerCatalog)
}

// IsAuthorizedPeer 判断设备是否已加入房间。
func (s *RoomService) IsAuthorizedPeer(deviceID string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, ok := s.members[strings.TrimSpace(deviceID)]
	return ok
}

// HostBaseURL 返回主机基础地址。
func (s *RoomService) HostBaseURL() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.hostBaseURL
}

// HostDeviceID 返回主机设备 ID。
func (s *RoomService) HostDeviceID() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.hostDeviceID
}

// Member 房间成员。
func (s *RoomService) Member(deviceID string) (model.Member, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	member, ok := s.members[strings.TrimSpace(deviceID)]
	return member, ok
}

// RoomID 返回房间 ID。
func (s *RoomService) RoomID() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.sessionID
}

// catalogLocked 在持锁状态下生成共享目录。
func (s *RoomService) catalogLocked() []model.SharedEntry {
	owners := make([]string, 0, len(s.ownerCatalogs))
	for ownerID := range s.ownerCatalogs {
		owners = append(owners, ownerID)
	}
	sort.Strings(owners)

	entries := make([]model.SharedEntry, 0)
	for _, ownerID := range owners {
		catalog := s.ownerCatalogs[ownerID]
		for _, file := range catalog.files {
			entries = append(entries, model.SharedEntry{
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
