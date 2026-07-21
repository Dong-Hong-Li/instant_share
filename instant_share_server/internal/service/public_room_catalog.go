package service

import (
	"sync"

	"instant_share/server/internal/model"
)

type PublicRoomCatalog struct {
	mu      sync.RWMutex
	entries []model.SharedEntry
}

func NewPublicRoomCatalog() *PublicRoomCatalog {
	return &PublicRoomCatalog{entries: nil}
}

func (s *PublicRoomCatalog) Set(entries []model.SharedEntry) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if entries == nil {
		s.entries = nil
		return
	}
	cp := make([]model.SharedEntry, len(entries))
	copy(cp, entries)
	s.entries = cp
}

func (s *PublicRoomCatalog) Clear() {
	s.Set(nil)
}

func (s *PublicRoomCatalog) Entries() []model.SharedEntry {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if len(s.entries) == 0 {
		return nil
	}
	cp := make([]model.SharedEntry, len(s.entries))
	copy(cp, s.entries)
	return cp
}
