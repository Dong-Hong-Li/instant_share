package service

import (
	"instant_share/server/internal/application/room/repository"
	"instant_share/server/internal/domain/room"
)

// MirrorService 公开目录镜像用例。
type MirrorService struct {
	mirror repository.PublicMirror
}

// NewMirrorService 创建镜像用例。
func NewMirrorService(mirror repository.PublicMirror) *MirrorService {
	return &MirrorService{mirror: mirror}
}

// Set 设置镜像目录。
func (s *MirrorService) Set(entries []room.SharedEntry) {
	s.mirror.Set(entries)
}

// Clear 清空镜像。
func (s *MirrorService) Clear() {
	s.mirror.Clear()
}

// Entries 读取镜像目录。
func (s *MirrorService) Entries() []room.SharedEntry {
	return s.mirror.Entries()
}
