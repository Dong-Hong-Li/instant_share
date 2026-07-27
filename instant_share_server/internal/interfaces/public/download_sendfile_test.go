package public

import (
	"io"
	"net"
	"net/http"
	"os"
	"testing"
	"time"

	sharememory "instant_share/server/internal/adapter/share/memory"
	sharesvc "instant_share/server/internal/application/share/service"
	"instant_share/server/internal/domain/share"
)

// TestAsHTTPContentHidesOsFile 确保下载内容不暴露 *os.File。
// 否则 net/http 会对非 loopback 连接走 macOS sendfile，可能在 sniffLen(512) 后乱序/断开
// （golang/go#79706）。
func TestAsHTTPContentHidesOsFile(t *testing.T) {
	f, err := os.CreateTemp(t.TempDir(), "share-*.bin")
	if err != nil {
		t.Fatalf("CreateTemp: %v", err)
	}
	t.Cleanup(func() { _ = f.Close() })

	content := asHTTPContent(f)
	if _, ok := content.(*os.File); ok {
		t.Fatal("asHTTPContent 不得返回 *os.File，否则会触发 macOS sendfile 路径")
	}
	if _, ok := asHTTPContent(f).(io.ReadSeeker); !ok {
		t.Fatal("asHTTPContent 必须实现 io.ReadSeeker（ServeContent 需要）")
	}
}

// TestShareFileDownloadOverLANCompletesBeyond512 经真实 TCP（优先 LAN）下载 >512B 文件，
// 校验完整字节与内容，覆盖「只能读 512 字节后断开」回归。
func TestShareFileDownloadOverLANCompletesBeyond512(t *testing.T) {
	const size = 2048
	payload := make([]byte, size)
	for i := range payload {
		payload[i] = byte(i % 251)
	}

	tmp, err := os.CreateTemp(t.TempDir(), "share-*.bin")
	if err != nil {
		t.Fatalf("CreateTemp: %v", err)
	}
	if _, err := tmp.Write(payload); err != nil {
		t.Fatalf("Write: %v", err)
	}
	path := tmp.Name()
	if err := tmp.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}

	store := sharememory.NewStore(0)
	svc := sharesvc.NewService(store, "0.0.0.0", 0)
	if _, err := svc.Start([]share.ShareFile{{
		ID:   "f-lan-512",
		Path: path,
		Name: "payload.bin",
		Size: int64(size),
	}}, 0); err != nil {
		t.Fatalf("Start: %v", err)
	}

	h := NewController(svc, nil, nil)
	mux := http.NewServeMux()
	h.Register(mux)

	ln, addr := listenPreferLAN(t)
	defer ln.Close()

	srv := &http.Server{Handler: mux}
	go func() { _ = srv.Serve(ln) }()
	t.Cleanup(func() {
		_ = srv.Close()
	})

	url := "http://" + addr + "/api/v1/share/files/f-lan-512/download"
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		t.Fatalf("GET %s: %v", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d body=%q", resp.StatusCode, body)
	}

	got, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("ReadAll: %v", err)
	}
	if len(got) != size {
		t.Fatalf("downloaded %d bytes, want %d（疑似 512 字节截断）", len(got), size)
	}
	for i := 0; i < size; i++ {
		if got[i] != payload[i] {
			t.Fatalf("byte[%d]=%d, want %d", i, got[i], payload[i])
		}
	}
}

// listenPreferLAN 优先绑定非 loopback IPv4，否则回退 127.0.0.1（sendfile 问题主要在 LAN）。
func listenPreferLAN(t *testing.T) (net.Listener, string) {
	t.Helper()
	ifaces, _ := net.Interfaces()
	for _, iface := range ifaces {
		addrs, _ := iface.Addrs()
		for _, a := range addrs {
			ipn, ok := a.(*net.IPNet)
			if !ok || ipn.IP.IsLoopback() || ipn.IP.To4() == nil {
				continue
			}
			ln, err := net.Listen("tcp", net.JoinHostPort(ipn.IP.String(), "0"))
			if err != nil {
				continue
			}
			return ln, ln.Addr().String()
		}
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen: %v", err)
	}
	return ln, ln.Addr().String()
}
