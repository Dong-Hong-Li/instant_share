//go:build !windows

package main

import (
	"os"
	"syscall"
)

// parentAlive 通过发送 0 信号判断进程是否存活（Unix）。
func parentAlive(pid int) bool {
	proc, err := os.FindProcess(pid)
	if err != nil {
		return false
	}
	return proc.Signal(syscall.Signal(0)) == nil
}
