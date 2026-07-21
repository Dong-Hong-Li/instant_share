package room

import (
	"errors"
	"time"
)

// PairingTTL 配对请求有效期。
const PairingTTL = 60 * time.Second

var (
	// ErrRoomNotActive 房间未开启。
	ErrRoomNotActive = errors.New("room is not active")
	// ErrPairingNotFound 配对请求不存在。
	ErrPairingNotFound = errors.New("pairing request not found")
	// ErrPairingExpired 配对请求已过期。
	ErrPairingExpired = errors.New("pairing request expired")
	// ErrInvalidRoomArgument 房间参数无效。
	ErrInvalidRoomArgument = errors.New("invalid room argument")
)
