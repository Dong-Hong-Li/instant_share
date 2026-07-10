//go:build windows

package main

import "syscall"

const stillActive = 259

// parentAlive 通过 OpenProcess + GetExitCodeProcess 判断父进程是否仍在运行。
func parentAlive(pid int) bool {
	const processQueryLimitedInformation = 0x1000
	handle, err := syscall.OpenProcess(processQueryLimitedInformation, false, uint32(pid))
	if err != nil {
		return false
	}
	defer syscall.CloseHandle(handle)

	var code uint32
	if err := syscall.GetExitCodeProcess(handle, &code); err != nil {
		return false
	}
	return code == stillActive
}
