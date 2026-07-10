package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"instant_share/server/internal/config"
	"instant_share/server/internal/runtime"
)

func main() {
	cfg := config.Load()

	rt, err := runtime.Start(cfg)
	if err != nil {
		log.Fatalf("server failed: %v", err)
	}
	port := rt.Port()
	log.Printf("instant-share server listening on http://127.0.0.1:%d/share (admin ws: ws://127.0.0.1:%d/ws)", port, port)
	// Flutter 子进程运行时解析此行获取系统分配端口。
	log.Printf("INSTANT_SHARE_READY port=%d", port)

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	// 父进程（Flutter App）退出时自动关闭，避免残留僵尸进程占用端口。
	if cfg.ParentPID > 0 {
		go watchParent(cfg.ParentPID, stop)
	}

	<-stop
	rt.Stop()
}

// watchParent 周期性检查父进程是否存活，父进程消失时触发优雅关闭。
func watchParent(pid int, stop chan<- os.Signal) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		if !parentAlive(pid) {
			log.Printf("parent process %d gone, shutting down", pid)
			stop <- syscall.SIGTERM
			return
		}
	}
}
