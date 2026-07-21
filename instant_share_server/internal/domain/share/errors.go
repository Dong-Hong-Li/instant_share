package share

import "errors"

var (
	// ErrShareNotActive 分享未开启。
	ErrShareNotActive = errors.New("share is not active")
	// ErrShareActive 分享已开启。
	ErrShareActive = errors.New("share is already active")
	// ErrNoFiles 无文件可分享。
	ErrNoFiles = errors.New("no files to share")
)
