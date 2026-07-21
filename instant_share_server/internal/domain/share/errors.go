package share

import "errors"

var (
	// ErrShareNotActive 分享未开启（Stop / Sync 时返回）。
	ErrShareNotActive = errors.New("share is not active")
	// ErrShareActive 分享已开启（重复 Start）。
	ErrShareActive = errors.New("share is already active")
	// ErrNoFiles 无文件可分享（预留；当前允许空文件列表 Start）。
	ErrNoFiles = errors.New("no files to share")
)
