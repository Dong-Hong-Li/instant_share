package service_test

import (
	"errors"
	"testing"

	"instant_share/server/internal/adapter/share/memory"
	"instant_share/server/internal/application/share/service"
	"instant_share/server/internal/domain/share"
)

func TestStopWhenInactive(t *testing.T) {
	store := memory.NewStore(8080)
	svc := service.NewService(store, "0.0.0.0", 8080)
	_, err := svc.Stop()
	if !errors.Is(err, share.ErrShareNotActive) {
		t.Fatalf("got %v", err)
	}
}

func TestStartThenStop(t *testing.T) {
	store := memory.NewStore(8080)
	svc := service.NewService(store, "0.0.0.0", 8080)

	// 使用空文件列表（现网允许空文件开启分享）。
	status, err := svc.Start(nil, 0)
	if err != nil {
		t.Fatalf("start: %v", err)
	}
	if !status.Active {
		t.Fatalf("expected active")
	}
	stopped, err := svc.Stop()
	if err != nil {
		t.Fatalf("stop: %v", err)
	}
	if stopped.Active {
		t.Fatalf("expected inactive")
	}
}
