package util

import (
	"net"
	"testing"
)

// TestLanIPPriority。
func TestLanIPPriority(t *testing.T) {
	tests := []struct {
		ip       string
		priority int
	}{
		{"192.168.1.10", 0},
		{"10.0.0.5", 1},
		{"172.17.0.1", 2},
		{"8.8.8.8", 3},
	}

	for _, tt := range tests {
		got := lanIPPriority(net.ParseIP(tt.ip).To4())
		if got != tt.priority {
			t.Fatalf("lanIPPriority(%s) = %d, want %d", tt.ip, got, tt.priority)
		}
	}
}

// TestPickBestCandidatePrefersReal192OverVirtual172。
func TestPickBestCandidatePrefersReal192OverVirtual172(t *testing.T) {
	candidates := []ipCandidate{
		{ip: net.ParseIP("172.22.128.1").To4(), priority: 2, virtual: true},
		{ip: net.ParseIP("192.168.31.100").To4(), priority: 0, virtual: false},
	}

	ip := pickBestCandidate(candidates, false, true)
	if ip == nil || ip.String() != "192.168.31.100" {
		t.Fatalf("pickBestCandidate() = %v, want 192.168.31.100", ip)
	}
}

// TestPickBestCandidatePrefers192Over172OnSameClass。
func TestPickBestCandidatePrefers192Over172OnSameClass(t *testing.T) {
	candidates := []ipCandidate{
		{ip: net.ParseIP("172.16.0.2").To4(), priority: 2, virtual: false},
		{ip: net.ParseIP("192.168.0.2").To4(), priority: 0, virtual: false},
	}

	ip := pickBestCandidate(candidates, false, true)
	if ip == nil || ip.String() != "192.168.0.2" {
		t.Fatalf("pickBestCandidate() = %v, want 192.168.0.2", ip)
	}
}

// TestLocalIPsOrdersPrimaryFirst。
func TestLocalIPsOrdersPrimaryFirst(t *testing.T) {
	candidates := []ipCandidate{
		{ip: net.ParseIP("10.0.0.5").To4(), priority: 1, virtual: false},
		{ip: net.ParseIP("192.168.1.10").To4(), priority: 0, virtual: false},
	}

	primary := primaryLocalIPFromCandidates(candidates)
	if primary != "192.168.1.10" {
		t.Fatalf("primaryLocalIPFromCandidates() = %s, want 192.168.1.10", primary)
	}
}

// TestLocalIPsDedupesAndSkipsVirtualPrivate。
func TestLocalIPsDedupesAndSkipsVirtualPrivate(t *testing.T) {
	candidates := []ipCandidate{
		{ip: net.ParseIP("192.168.1.10").To4(), priority: 0, virtual: false},
		{ip: net.ParseIP("192.168.1.10").To4(), priority: 0, virtual: false},
		{ip: net.ParseIP("10.0.0.5").To4(), priority: 1, virtual: false},
		{ip: net.ParseIP("172.17.0.1").To4(), priority: 2, virtual: true},
	}

	primary := primaryLocalIPFromCandidates(candidates)
	seen := map[string]struct{}{primary: {}}

	// scoredIP。
	type scoredIP struct {
		ip       string
		priority int
	}
	// rest。
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

	if len(rest) != 1 || rest[0].ip != "10.0.0.5" {
		t.Fatalf("rest = %+v, want only 10.0.0.5", rest)
	}
}

// TestIsVirtualInterface。
func TestIsVirtualInterface(t *testing.T) {
	tests := []struct {
		name    string
		virtual bool
	}{
		{"vEthernet (WSL)", true},
		{"vEthernet (Default Switch)", true},
		{"DockerNAT", true},
		{"Wi-Fi", false},
		{"Ethernet", false},
		{"en0", false},
	}

	for _, tt := range tests {
		got := isVirtualInterface(tt.name)
		if got != tt.virtual {
			t.Fatalf("isVirtualInterface(%q) = %v, want %v", tt.name, got, tt.virtual)
		}
	}
}
