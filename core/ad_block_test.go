package main

import (
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/gofrs/uuid/v5"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

type fakeAdBlockTracker struct {
	info *statistic.TrackerInfo
}

func (f fakeAdBlockTracker) ID() string {
	return f.info.UUID.String()
}

func (f fakeAdBlockTracker) Close() error {
	return nil
}

func (f fakeAdBlockTracker) Info() *statistic.TrackerInfo {
	return f.info
}

func (f fakeAdBlockTracker) Chains() C.Chain {
	return f.info.Chain
}

func (f fakeAdBlockTracker) ProviderChains() C.Chain {
	return f.info.ProviderChain
}

func (f fakeAdBlockTracker) AppendToChains(adapter C.ProxyAdapter) {}

func (f fakeAdBlockTracker) RemoteDestination() string {
	return ""
}

func TestAdBlockRingCapacityAndOrder(t *testing.T) {
	adBlockEvents.clear()

	for i := 0; i < adBlockEventCapacity+5; i++ {
		adBlockEvents.add(AdBlockEvent{ID: fmt.Sprintf("event-%03d", i)})
	}

	snapshot := adBlockEvents.snapshot()
	if len(snapshot.Events) != adBlockEventCapacity {
		t.Fatalf("events length = %d, want %d", len(snapshot.Events), adBlockEventCapacity)
	}
	if snapshot.Events[0].ID != "event-504" {
		t.Fatalf("newest event = %q, want event-504", snapshot.Events[0].ID)
	}
	if snapshot.Events[len(snapshot.Events)-1].ID != "event-005" {
		t.Fatalf("oldest event = %q, want event-005", snapshot.Events[len(snapshot.Events)-1].ID)
	}
	if snapshot.TotalBlocked != adBlockEventCapacity+5 || snapshot.SessionBlocked != adBlockEventCapacity+5 {
		t.Fatalf("counts = %d/%d, want %d", snapshot.TotalBlocked, snapshot.SessionBlocked, adBlockEventCapacity+5)
	}
}

func TestAdBlockRingConcurrentWrites(t *testing.T) {
	adBlockEvents.clear()

	const count = 1000
	var wg sync.WaitGroup
	wg.Add(count)
	for i := 0; i < count; i++ {
		go func(i int) {
			defer wg.Done()
			adBlockEvents.add(AdBlockEvent{ID: fmt.Sprintf("event-%03d", i)})
		}(i)
	}
	wg.Wait()

	snapshot := adBlockEvents.snapshot()
	if len(snapshot.Events) != adBlockEventCapacity {
		t.Fatalf("events length = %d, want %d", len(snapshot.Events), adBlockEventCapacity)
	}
	if snapshot.TotalBlocked != count || snapshot.SessionBlocked != count {
		t.Fatalf("counts = %d/%d, want %d", snapshot.TotalBlocked, snapshot.SessionBlocked, count)
	}
}

func TestClearAdBlockEvents(t *testing.T) {
	adBlockEvents.clear()
	adBlockEvents.add(AdBlockEvent{ID: "event"})
	if !handleClearAdBlockEvents() {
		t.Fatal("handleClearAdBlockEvents returned false")
	}

	snapshot := adBlockEvents.snapshot()
	if len(snapshot.Events) != 0 {
		t.Fatalf("events length = %d, want 0", len(snapshot.Events))
	}
	if snapshot.TotalBlocked != 0 || snapshot.SessionBlocked != 0 {
		t.Fatalf("counts = %d/%d, want 0/0", snapshot.TotalBlocked, snapshot.SessionBlocked)
	}
}

func TestNormalizeAdBlockDomain(t *testing.T) {
	tests := map[string]string{
		"HTTP://Example.COM:443/path?q=1": "example.com",
		"+.Ads.Example.com.":              "ads.example.com",
		"www.example.co.uk":               "www.example.co.uk",
	}
	for input, want := range tests {
		got := handleNormalizeAdBlockDomain(input)
		if got != want {
			t.Fatalf("normalize(%q) = %q, want %q", input, got, want)
		}
	}

	for _, input := range []string{"", "com", "co.uk", "127.0.0.1", "bad..example.com"} {
		if got := handleNormalizeAdBlockDomain(input); got != "" {
			t.Fatalf("normalize(%q) = %q, want empty", input, got)
		}
	}
}

func TestNoAdRejectClassification(t *testing.T) {
	noAdInfo := newTrackerInfo(adBlockRemoteProviderName, C.Chain{"REJECT"})
	if !isNoAdRejectedTracker(noAdInfo) {
		t.Fatal("NoAd RuleSet REJECT tracker was not classified")
	}

	ordinaryReject := newTrackerInfo("ordinary_provider", C.Chain{"REJECT"})
	if isNoAdRejectedTracker(ordinaryReject) {
		t.Fatal("ordinary REJECT tracker was classified as NoAd")
	}

	noAdDirect := newTrackerInfo(adBlockRemoteProviderName, C.Chain{"DIRECT"})
	if isNoAdRejectedTracker(noAdDirect) {
		t.Fatal("NoAd provider with non-REJECT chain was classified as blocked")
	}
}

func TestRecordAdBlockEventCachesWithoutListener(t *testing.T) {
	adBlockEvents.clear()
	info := newTrackerInfo(adBlockLocalBlockProviderName, C.Chain{"REJECT"})
	info.Metadata = &C.Metadata{
		Host:    "ads.example.com",
		DstPort: 443,
		NetWork: C.TCP,
		Process: "com.example.app",
		Uid:     12345,
	}

	event, ok := recordAdBlockEvent(fakeAdBlockTracker{info: info})
	if !ok {
		t.Fatal("recordAdBlockEvent returned false")
	}
	if event.Host != "ads.example.com" || event.PackageName != "com.example.app" || event.UID != 12345 {
		t.Fatalf("unexpected event: %+v", event)
	}

	snapshot := adBlockEvents.snapshot()
	if len(snapshot.Events) != 1 || snapshot.SessionBlocked != 1 || snapshot.TotalBlocked != 1 {
		t.Fatalf("unexpected snapshot after record: %+v", snapshot)
	}
}

func newTrackerInfo(provider string, chain C.Chain) *statistic.TrackerInfo {
	id, err := uuid.NewV4()
	if err != nil {
		panic(err)
	}
	return &statistic.TrackerInfo{
		UUID:        id,
		Start:       time.Now(),
		Rule:        "RuleSet",
		RulePayload: provider,
		Chain:       chain,
		Metadata:    &C.Metadata{},
	}
}
