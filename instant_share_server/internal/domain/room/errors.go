package room

import (
	"errors"
	"time"
)

// PairingTTL 配对请求有效期；超时后 SweepExpired 清理并通知 Peer pairing.timeout。
const PairingTTL = 60 * time.Second

var (
	// ErrRoomNotActive 房间未开启（未 EnsureRoom 或已 Close）。
	ErrRoomNotActive = errors.New("room is not active")
	// ErrPairingNotFound 待审批列表中无该设备。
	ErrPairingNotFound = errors.New("pairing request not found")
	// ErrPairingExpired 配对请求已过期。
	ErrPairingExpired = errors.New("pairing request expired")
	// ErrInvalidRoomArgument 设备 ID / BaseURL 等参数非法。
	ErrInvalidRoomArgument = errors.New("invalid room argument")
)
