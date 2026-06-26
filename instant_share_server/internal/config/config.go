package config

import (
	"flag"
	"net"
	"os"
	"strconv"
)

// Config 服务运行配置。
type Config struct {
	Host      string
	Port      int
	ParentPID int
	WebSocket WebSocketConfig
}

// Load 从命令行与环境变量加载配置。
func Load() Config {
	defaultPort := 8080
	if v := os.Getenv("INSTANT_SHARE_PORT"); v != "" {
		if p, err := strconv.Atoi(v); err == nil {
			defaultPort = p
		}
	}

	defaultParentPID := 0
	if v := os.Getenv("INSTANT_SHARE_PARENT_PID"); v != "" {
		if p, err := strconv.Atoi(v); err == nil {
			defaultParentPID = p
		}
	}

	host := flag.String("host", envOr("INSTANT_SHARE_HOST", "0.0.0.0"), "监听地址")
	port := flag.Int("port", defaultPort, "HTTP 服务端口")
	parentPID := flag.Int("parent-pid", defaultParentPID, "父进程 PID，存活监控；父进程退出时自动关闭")
	flag.Parse()

	return Config{
		Host:      *host,
		Port:      *port,
		ParentPID: *parentPID,
		WebSocket: DefaultWebSocketConfig(),
	}
}

// Addr 返回 HTTP 监听地址。
func (c Config) Addr() string {
	return net.JoinHostPort(c.Host, strconv.Itoa(c.Port))
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
