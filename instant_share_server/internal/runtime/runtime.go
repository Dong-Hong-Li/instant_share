package runtime

import (
	"context"
	"log"
	"net"
	"net/http"
	"sync"
	"time"

	"instant_share/server/cmd"
	"instant_share/server/config"
)

// Runtime 封装一个正在运行的 HTTP/WebSocket 服务实例。
type Runtime struct {
	mu       sync.Mutex
	deps     *cmd.AppDeps
	cleanup  func()
	server   *http.Server
	listener net.Listener
	port     int
}

// Start 监听并在后台 goroutine 中启动服务。
func Start(cfg config.Config) (*Runtime, error) {
	ln, err := net.Listen("tcp", cfg.Addr())
	if err != nil {
		return nil, err
	}

	cfg.Port = ln.Addr().(*net.TCPAddr).Port

	handler, deps, cleanup, err := cmd.Bootstrap(cfg)
	if err != nil {
		_ = ln.Close()
		return nil, err
	}

	server := &http.Server{Handler: handler}

	rt := &Runtime{
		deps:     deps,
		cleanup:  cleanup,
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

// Deps 返回底层依赖（供测试或生命周期收尾）。
func (r *Runtime) Deps() *cmd.AppDeps {
	return r.deps
}

// Stop 优雅关闭服务（含进行中的分享会话与 WebSocket 连接）。幂等。
func (r *Runtime) Stop() {
	r.mu.Lock()
	defer r.mu.Unlock()

	if r.server == nil {
		return
	}

	if r.deps != nil && r.deps.Share.Status().Active {
		_, _ = r.deps.Share.Stop()
	}
	if r.deps != nil && r.deps.WS != nil {
		_ = r.deps.WS.Close()
	}
	if r.cleanup != nil {
		r.cleanup()
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := r.server.Shutdown(ctx); err != nil {
		log.Printf("instant-share server shutdown error: %v", err)
	}

	r.server = nil
}
