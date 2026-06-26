package runtime

import (
	"context"
	"log"
	"net"
	"net/http"
	"sync"
	"time"

	"instant_share/server/internal/app"
	"instant_share/server/internal/config"
)

// Runtime 封装一个正在运行的 HTTP/WebSocket 服务实例。
//
// 与 cmd/server（独立二进制，子进程模式）和 cmd/lib（c-shared 库，进程内模式）
// 共用同一套启停逻辑：先监听拿到实际端口，再构建 app，最后在 goroutine 中 Serve。
type Runtime struct {
	mu       sync.Mutex
	app      *app.App
	server   *http.Server
	listener net.Listener
	port     int
}

// Start 监听并在后台 goroutine 中启动服务。
//
// 当 cfg.Port 为 0 时由系统分配空闲端口；返回的 Runtime 通过 Port() 暴露实际端口，
// 便于移动端避免端口冲突（桌面端可继续固定 8080）。
func Start(cfg config.Config) (*Runtime, error) {
	ln, err := net.Listen("tcp", cfg.Addr())
	if err != nil {
		return nil, err
	}

	// 用实际监听端口回填配置，保证 ServerHealth / 分享链接里的端口正确。
	cfg.Port = ln.Addr().(*net.TCPAddr).Port

	application := app.New(cfg)
	server := &http.Server{Handler: application.Mux}

	rt := &Runtime{
		app:      application,
		server:   server,
		listener: ln,
		port:     cfg.Port,
	}

	go func() {
		if err := server.Serve(ln); err != nil && err != http.ErrServerClosed {
			log.Printf("instant-share server serve error: %v", err)
		}
	}()

	return rt, nil
}

// Port 返回实际监听端口。
func (r *Runtime) Port() int {
	return r.port
}

// App 返回底层应用实例（供独立二进制做生命周期收尾）。
func (r *Runtime) App() *app.App {
	return r.app
}

// Stop 优雅关闭服务（含进行中的分享会话与 WebSocket 连接）。幂等。
func (r *Runtime) Stop() {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.server == nil {
		return
	}

	if r.app.Share.Status().Active {
		_, _ = r.app.Share.Stop()
	}
	if r.app.WS != nil {
		_ = r.app.WS.Close()
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := r.server.Shutdown(ctx); err != nil {
		log.Printf("instant-share server shutdown error: %v", err)
	}

	r.server = nil
}
