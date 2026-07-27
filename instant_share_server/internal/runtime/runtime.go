// Package runtime 封装 instant-share HTTP/WebSocket 服务的启动与优雅关停。
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

// noReadFromConn 隐藏底层 Conn 的 ReadFrom，强制 net/http 走普通 Write 循环，
// 避免 macOS sendfile 与 ResponseWriter 在非 loopback 上乱序（golang/go#79706）。
type noReadFromConn struct{ net.Conn }

// noReadFromListener 包装 Listener，Accept 时返回 noReadFromConn。
type noReadFromListener struct{ net.Listener }

func (l noReadFromListener) Accept() (net.Conn, error) {
	c, err := l.Listener.Accept()
	if err != nil {
		return nil, err
	}
	return noReadFromConn{Conn: c}, nil
}

// Runtime 封装一个正在运行的 HTTP/WebSocket 服务实例。
type Runtime struct {
	mu       sync.Mutex
	deps     *cmd.AppDeps   // bootstrap 装配的依赖容器
	cleanup  func()         // 额外清理（如 room WS Stop）
	server   *http.Server   // HTTP 服务
	listener net.Listener   // 实际监听 socket（可能随机端口）
	port     int            // 解析后的监听端口
}

/**
 * @description: Start 监听 cfg.Addr、Bootstrap 依赖并在后台 goroutine 启动 HTTP 服务。
 * 若 Addr 端口为 0，会使用系统分配的实际端口写回 cfg.Port。
 * @param {config.Config} cfg 服务配置
 * @return {*Runtime} 运行中实例
 * @return {error} 监听或 Bootstrap 失败
 */
func Start(cfg config.Config) (*Runtime, error) {
	rawLn, err := net.Listen("tcp", cfg.Addr())
	if err != nil {
		return nil, err
	}
	// 禁用 sendfile 快路径，保证局域网下载完整（Mac 端分享常见场景）。
	ln := net.Listener(noReadFromListener{Listener: rawLn})

	cfg.Port = rawLn.Addr().(*net.TCPAddr).Port

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

/**
 * @description: Stop 优雅关闭服务：先停分享、关 WS、执行 cleanup，再 Shutdown HTTP。幂等。
 */
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
