package service

import (
	"instant_share/server/internal/application/room/repository"
	"instant_share/server/internal/domain/room"
)

// MirrorService 公开目录镜像用例。
//
// Peer 在 Host 上聚合跨设备完整目录后，经 room.public_catalog.sync 写入镜像；
// buildPublicStatus 在「非权威 Host」时优先展示镜像而非 Host 本地 room 目录。
type MirrorService struct {
	mirror repository.PublicMirror
}

// NewMirrorService 创建镜像用例。
func NewMirrorService(mirror repository.PublicMirror) *MirrorService {
	return &MirrorService{mirror: mirror}
}

// Set 覆盖 Peer 同步来的公开目录镜像。
func (s *MirrorService) Set(entries []room.SharedEntry) {
	s.mirror.Set(entries)
}

// Clear 清空镜像（share.stop 或 public_catalog.clear 时调用）。
func (s *MirrorService) Clear() {
	s.mirror.Clear()
}

// Entries 读取镜像目录副本；空时返回 nil。
func (s *MirrorService) Entries() []room.SharedEntry {
	return s.mirror.Entries()
}
