package util

import (
	"fmt"
	"net"
	"sort"
	"strings"
)

type ipCandidate struct {
	ip       net.IP
	priority int
	virtual  bool
}

// PrimaryLocalIP 返回用于局域网分享的 IPv4 地址。
//
// 旧实现直接返回首个非回环 IPv4，在 Windows 上常会误选 Docker/WSL/Hyper-V
// 等虚拟网卡的 172.x 地址。现改为优先真实网卡上的 RFC1918 私网地址。
func PrimaryLocalIP() string {
	candidates := collectIPCandidates()
	if len(candidates) == 0 {
		return "127.0.0.1"
	}
	return primaryLocalIPFromCandidates(candidates)
}

// LocalIPs 返回可用于局域网分享的 IPv4 列表，按优先级排序、去重。
// 首个元素与 PrimaryLocalIP 一致。
func LocalIPs() []string {
	candidates := collectIPCandidates()
	if len(candidates) == 0 {
		return []string{"127.0.0.1"}
	}

	primary := primaryLocalIPFromCandidates(candidates)
	seen := map[string]struct{}{primary: {}}
	ips := []string{primary}

	type scoredIP struct {
		ip       string
		priority int
	}
	var rest []scoredIP
	for _, candidate := range candidates {
		if candidate.virtual || !isPrivateIPv4(candidate.ip) {
			continue
		}
		ip := candidate.ip.String()
		if _, ok := seen[ip]; ok {
			continue
		}
		rest = append(rest, scoredIP{ip: ip, priority: candidate.priority})
	}

	sort.SliceStable(rest, func(i, j int) bool {
		return rest[i].priority < rest[j].priority
	})
	for _, item := range rest {
		if _, ok := seen[item.ip]; ok {
			continue
		}
		seen[item.ip] = struct{}{}
		ips = append(ips, item.ip)
	}

	return ips
}

func collectIPCandidates() []ipCandidate {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil
	}

	var candidates []ipCandidate
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		virtual := isVirtualInterface(iface.Name)
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		for _, addr := range addrs {
			ipNet, ok := addr.(*net.IPNet)
			if !ok || ipNet.IP.IsLoopback() {
				continue
			}
			ip4 := ipNet.IP.To4()
			if ip4 == nil || isLinkLocalIPv4(ip4) {
				continue
			}
			candidates = append(candidates, ipCandidate{
				ip:       ip4,
				priority: lanIPPriority(ip4),
				virtual:  virtual,
			})
		}
	}

	return candidates
}

func primaryLocalIPFromCandidates(candidates []ipCandidate) string {
	if ip := pickBestCandidate(candidates, false, true); ip != nil {
		return ip.String()
	}
	if ip := pickBestCandidate(candidates, true, true); ip != nil {
		return ip.String()
	}
	if ip := pickBestCandidate(candidates, false, false); ip != nil {
		return ip.String()
	}
	return candidates[0].ip.String()
}

func pickBestCandidate(candidates []ipCandidate, includeVirtual, privateOnly bool) net.IP {
	var best *ipCandidate
	for i := range candidates {
		c := &candidates[i]
		if !includeVirtual && c.virtual {
			continue
		}
		if privateOnly && !isPrivateIPv4(c.ip) {
			continue
		}
		if best == nil || c.priority < best.priority {
			best = c
		}
	}
	if best == nil {
		return nil
	}
	return best.ip
}

func isLinkLocalIPv4(ip net.IP) bool {
	return ip[0] == 169 && ip[1] == 254
}

func isPrivateIPv4(ip net.IP) bool {
	switch {
	case ip[0] == 10:
		return true
	case ip[0] == 172 && ip[1] >= 16 && ip[1] <= 31:
		return true
	case ip[0] == 192 && ip[1] == 168:
		return true
	default:
		return false
	}
}

// lanIPPriority 数值越小越优先：192.168 > 10.x > 172.16-31 > 其他。
func lanIPPriority(ip net.IP) int {
	switch {
	case ip[0] == 192 && ip[1] == 168:
		return 0
	case ip[0] == 10:
		return 1
	case ip[0] == 172 && ip[1] >= 16 && ip[1] <= 31:
		return 2
	default:
		return 3
	}
}

func isVirtualInterface(name string) bool {
	lower := strings.ToLower(name)
	patterns := []string{
		"docker",
		"veth",
		"wsl",
		"hyper-v",
		"hyperv",
		"vethernet",
		"virtualbox",
		"vbox",
		"vmware",
		"vmnet",
		"virtual ethernet",
		"tailscale",
		"zerotier",
		"npcap",
		"bluetooth",
		"isatap",
		"teredo",
	}
	for _, pattern := range patterns {
		if strings.Contains(lower, pattern) {
			return true
		}
	}
	return false
}

// FormatSize 格式化文件大小。
func FormatSize(size int64) string {
	const unit = 1024
	if size < unit {
		return fmt.Sprintf("%d B", size)
	}

	div, exp := int64(unit), 0
	for n := size / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	units := []string{"KB", "MB", "GB", "TB"}
	return fmt.Sprintf("%.1f %s", float64(size)/float64(div), units[exp])
}
