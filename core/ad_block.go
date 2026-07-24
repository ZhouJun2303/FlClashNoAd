package main

import (
	"errors"
	"net"
	"net/netip"
	"net/url"
	"sort"
	"strings"
	"sync"
	"time"

	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"golang.org/x/net/idna"
	"golang.org/x/net/publicsuffix"
)

const (
	adBlockEventCapacity          = 500
	adBlockRemoteProviderName     = "__noad_anti_ad"
	adBlockAllowProviderName      = "__noad_allow"
	adBlockLocalBlockProviderName = "__noad_local_block"
	adBlockRuleVersion            = "anti-ad:mihomo.mrs"
)

var noAdRuleProviders = map[string]string{
	adBlockRemoteProviderName:     "anti-ad",
	adBlockLocalBlockProviderName: "manual",
}

type AdBlockEvent struct {
	ID              string    `json:"id"`
	Time            time.Time `json:"time"`
	Host            string    `json:"host"`
	DestinationIP   string    `json:"destinationIp,omitempty"`
	DestinationPort uint16    `json:"destinationPort,omitempty"`
	Network         string    `json:"network"`
	PackageName     string    `json:"packageName,omitempty"`
	UID             uint32    `json:"uid,omitempty"`
	Source          string    `json:"source"`
	Rule            string    `json:"rule"`
	RuleProvider    string    `json:"ruleProvider"`
	RuleVersion     string    `json:"ruleVersion,omitempty"`
}

type AdBlockSnapshot struct {
	Events         []AdBlockEvent `json:"events"`
	TotalBlocked   uint64         `json:"totalBlocked"`
	SessionBlocked uint64         `json:"sessionBlocked"`
	Capacity       int            `json:"capacity"`
	RuleVersion    string         `json:"ruleVersion"`
}

type AdBlockMatchResult struct {
	Matched        bool   `json:"matched"`
	Source         string `json:"source,omitempty"`
	Rule           string `json:"rule,omitempty"`
	NormalizedHost string `json:"normalizedHost,omitempty"`
}

type adBlockEventRing struct {
	mu             sync.Mutex
	events         []AdBlockEvent
	next           int
	totalBlocked   uint64
	sessionBlocked uint64
}

var adBlockEvents = &adBlockEventRing{
	events: make([]AdBlockEvent, 0, adBlockEventCapacity),
}

func (r *adBlockEventRing) add(event AdBlockEvent) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if len(r.events) < adBlockEventCapacity {
		r.events = append(r.events, event)
	} else {
		r.events[r.next] = event
	}
	r.next = (r.next + 1) % adBlockEventCapacity
	r.totalBlocked++
	r.sessionBlocked++
}

func (r *adBlockEventRing) snapshot() AdBlockSnapshot {
	r.mu.Lock()
	defer r.mu.Unlock()

	count := len(r.events)
	events := make([]AdBlockEvent, 0, count)
	for i := 0; i < count; i++ {
		idx := (r.next - 1 - i + adBlockEventCapacity) % adBlockEventCapacity
		if idx >= count {
			continue
		}
		events = append(events, r.events[idx])
	}

	return AdBlockSnapshot{
		Events:         events,
		TotalBlocked:   r.totalBlocked,
		SessionBlocked: r.sessionBlocked,
		Capacity:       adBlockEventCapacity,
		RuleVersion:    adBlockRuleVersion,
	}
}

func (r *adBlockEventRing) clear() {
	r.mu.Lock()
	defer r.mu.Unlock()

	r.events = r.events[:0]
	r.next = 0
	r.totalBlocked = 0
	r.sessionBlocked = 0
}

func recordAdBlockEvent(tracker statistic.Tracker) (*AdBlockEvent, bool) {
	info := tracker.Info()
	if info == nil || !isNoAdRejectedTracker(info) {
		return nil, false
	}

	event := adBlockEventFromTracker(info)
	adBlockEvents.add(event)
	return &event, true
}

func isNoAdRejectedTracker(info *statistic.TrackerInfo) bool {
	if normalizeRuleName(info.Rule) != "ruleset" {
		return false
	}
	if _, ok := noAdRuleProviders[info.RulePayload]; !ok {
		return false
	}
	return chainHasReject(info.Chain)
}

func normalizeRuleName(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = strings.ReplaceAll(value, "-", "")
	value = strings.ReplaceAll(value, "_", "")
	return value
}

func chainHasReject(chain C.Chain) bool {
	for _, item := range chain {
		if normalizeRuleName(item) == "reject" {
			return true
		}
	}
	return false
}

func adBlockEventFromTracker(info *statistic.TrackerInfo) AdBlockEvent {
	metadata := info.Metadata
	event := AdBlockEvent{
		ID:           info.UUID.String(),
		Time:         info.Start,
		Source:       noAdRuleProviders[info.RulePayload],
		Rule:         info.Rule,
		RuleProvider: info.RulePayload,
		RuleVersion:  adBlockRuleVersion,
	}
	if event.Time.IsZero() {
		event.Time = time.Now()
	}
	if metadata == nil {
		return event
	}

	event.Host = metadata.RuleHost()
	if event.Host == "" {
		event.Host = metadata.String()
	}
	if metadata.DstIP.IsValid() {
		event.DestinationIP = metadata.DstIP.String()
	}
	event.DestinationPort = metadata.DstPort
	event.Network = metadata.NetWork.String()
	event.PackageName = metadata.Process
	event.UID = metadata.Uid
	return event
}

func handleGetAdBlockSnapshot() AdBlockSnapshot {
	return adBlockEvents.snapshot()
}

func handleClearAdBlockEvents() bool {
	adBlockEvents.clear()
	return true
}

func handleNormalizeAdBlockDomain(input string) string {
	domain, err := normalizeAdBlockDomain(input)
	if err != nil {
		return ""
	}
	return domain
}

func handleMatchAdBlockDomain(input string) AdBlockMatchResult {
	domain, err := normalizeAdBlockDomain(input)
	if err != nil {
		return AdBlockMatchResult{}
	}

	providers := tunnel.RuleProviders()
	checks := []struct {
		name   string
		source string
	}{
		{name: adBlockAllowProviderName, source: "allow"},
		{name: adBlockLocalBlockProviderName, source: "manual"},
		{name: adBlockRemoteProviderName, source: "anti-ad"},
	}

	for _, check := range checks {
		provider, ok := providers[check.name]
		if !ok || !providerMatchesDomain(provider, domain) {
			continue
		}
		return AdBlockMatchResult{
			Matched:        true,
			Source:         check.source,
			Rule:           check.name,
			NormalizedHost: domain,
		}
	}

	return AdBlockMatchResult{NormalizedHost: domain}
}

func providerMatchesDomain(provider P.RuleProvider, domain string) bool {
	metadata := &C.Metadata{Host: domain}
	return provider.Match(metadata, C.RuleMatchHelper{})
}

func normalizeAdBlockDomain(input string) (string, error) {
	host := extractDomainHost(input)
	if host == "" {
		return "", errors.New("empty domain")
	}

	host = strings.TrimPrefix(host, "+.")
	host = strings.TrimPrefix(host, "*.")
	host = strings.TrimPrefix(host, ".")
	host = strings.TrimSuffix(host, ".")
	host = strings.ToLower(strings.TrimSpace(host))
	if host == "" || strings.Contains(host, "..") {
		return "", errors.New("invalid domain")
	}
	if _, err := netip.ParseAddr(host); err == nil {
		return "", errors.New("ip address is not a domain")
	}

	ascii, err := idna.Lookup.ToASCII(host)
	if err != nil {
		return "", err
	}
	ascii = strings.ToLower(strings.TrimSuffix(ascii, "."))
	if !hasValidDomainLabels(ascii) {
		return "", errors.New("invalid domain labels")
	}
	if _, err := publicsuffix.EffectiveTLDPlusOne(ascii); err != nil {
		return "", err
	}
	publicSuffix, _ := publicsuffix.PublicSuffix(ascii)
	if publicSuffix == ascii {
		return "", errors.New("domain must not be a public suffix")
	}
	return ascii, nil
}

func extractDomainHost(input string) string {
	value := strings.TrimSpace(input)
	if value == "" {
		return ""
	}
	if strings.Contains(value, "://") {
		parsed, err := url.Parse(value)
		if err == nil {
			return parsed.Hostname()
		}
	}
	if idx := strings.IndexAny(value, "/?#"); idx >= 0 {
		value = value[:idx]
	}
	if host, _, err := net.SplitHostPort(value); err == nil {
		return strings.Trim(host, "[]")
	}
	return strings.Trim(value, "[]")
}

func hasValidDomainLabels(domain string) bool {
	if len(domain) > 253 {
		return false
	}
	labels := strings.Split(domain, ".")
	if len(labels) < 2 {
		return false
	}
	for _, label := range labels {
		if len(label) == 0 || len(label) > 63 {
			return false
		}
		if label[0] == '-' || label[len(label)-1] == '-' {
			return false
		}
	}
	return true
}

func sortedNoAdProviderNames() []string {
	names := make([]string, 0, len(noAdRuleProviders))
	for name := range noAdRuleProviders {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}
