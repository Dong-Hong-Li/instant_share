// Package main 以 c-shared 模式编译为动态库（macOS .dylib / Windows .dll /
// Linux .so / Android .so），供 Flutter 通过 dart:ffi 进程内调用。
//
// 构建（macOS 原生 arm64）：
//
//	CGO_ENABLED=1 go build -buildmode=c-shared -o libinstantshare.dylib ./cmd/lib
//
// 跨平台/通用库见 build_lib.sh。
//
// iOS 不支持 dlopen 任意动态库，需改用 c-archive 静态库（.a）静态链接，
// 导出符号一致（StartServer/StopServer），后续补充。
package main

import "C"

import (
	"sync"

	"instant_share/server/internal/config"
	"instant_share/server/internal/runtime"
)

var (
	mu      sync.Mutex
	current *runtime.Runtime
)

// StartServer 在进程内启动分享服务，返回实际监听端口；失败返回 -1。
//
// port 传 0 时由系统分配空闲端口（移动端推荐，避免端口冲突）；
// 重复调用直接返回已运行实例的端口（幂等）。
//
//export StartServer
func StartServer(port C.int) C.int {
	mu.Lock()
	defer mu.Unlock()

	if current != nil {
		return C.int(current.Port())
	}

	cfg := config.Config{
		Host:      "0.0.0.0",
		Port:      int(port),
		WebSocket: config.DefaultWebSocketConfig(),
	}

	started, err := runtime.Start(cfg)
	if err != nil {
		return -1
	}

	current = started
	return C.int(started.Port())
}

// StopServer 优雅关闭进程内服务。幂等。
//
//export StopServer
func StopServer() {
	mu.Lock()
	defer mu.Unlock()

	if current == nil {
		return
	}
	current.Stop()
	current = nil
}

func main() {}
