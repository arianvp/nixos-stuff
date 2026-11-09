package main

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	externaljwtv1 "k8s.io/externaljwt/apis/v1"
)

// withCache makes the fixture's signer keep its keys in a cache, and fills it
func (f *fixture) withCache(t *testing.T) string {
	t.Helper()
	f.keys.cache = filepath.Join(t.TempDir(), "keys.json")
	if err := f.keys.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	return f.keys.cache
}

// restarted is a new signer process with the same configuration
func (f *fixture) restarted() *signer {
	bao := &openbao{address: f.keys.bao.address, authMount: f.keys.bao.authMount, http: f.keys.bao.http}
	keys := &keyset{bao: bao, mount: f.keys.mount, key: f.keys.key, now: f.clock.now, cache: f.keys.cache}
	return &signer{keys: keys, maxExpiry: time.Hour}
}

func kids(t *testing.T, s *signer) []string {
	t.Helper()
	resp, err := s.FetchKeys(context.Background(), &externaljwtv1.FetchKeysRequest{})
	if err != nil {
		t.Fatal(err)
	}
	var kids []string
	for _, k := range resp.Keys {
		kids = append(kids, k.KeyId)
	}
	return kids
}

func initialize(t *testing.T, s *signer) error {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	return s.keys.initialize(ctx)
}

func TestCacheServesKeysWhileOpenBaoIsDown(t *testing.T) {
	f := newFixture(t, 2*time.Hour, time.Hour)
	path := f.withCache(t)
	want := kids(t, f.signer())
	_, fetched := f.keys.all()
	if info, err := os.Stat(path); err != nil {
		t.Fatal(err)
	} else if info.Mode().Perm() != 0o600 {
		t.Errorf("cache mode = %v, want 0600", info.Mode().Perm())
	}

	f.server.Close()
	s := f.restarted()
	if err := initialize(t, s); err != nil {
		t.Fatalf("did not start from the cache: %v", err)
	}

	if got := kids(t, s); !slices.Equal(got, want) {
		t.Errorf("cached keys = %v, want %v", got, want)
	}
	resp, err := s.FetchKeys(context.Background(), &externaljwtv1.FetchKeysRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if !resp.DataTimestamp.AsTime().Equal(fetched) {
		t.Errorf("data timestamp = %v, want when the keys were read from OpenBao, %v", resp.DataTimestamp.AsTime(), fetched)
	}
	if _, err := s.Metadata(context.Background(), &externaljwtv1.MetadataRequest{}); err != nil {
		t.Error(err)
	}
	_, err = s.Sign(context.Background(), &externaljwtv1.SignJWTRequest{Claims: "e30"})
	if status.Code(err) != codes.Unavailable {
		t.Errorf("Sign = %v, want Unavailable", err)
	}
}

func TestSignsOnceOpenBaoIsBack(t *testing.T) {
	f := newFixture(t, time.Hour)
	f.withCache(t)
	f.fake.mu.Lock()
	f.fake.down = true
	f.fake.mu.Unlock()
	s := f.restarted()
	if err := initialize(t, s); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Sign(context.Background(), &externaljwtv1.SignJWTRequest{Claims: "e30"}); status.Code(err) != codes.Unavailable {
		t.Errorf("Sign = %v, want Unavailable", err)
	}

	f.fake.mu.Lock()
	f.fake.down = false
	f.fake.mu.Unlock()
	if err := s.keys.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Sign(context.Background(), &externaljwtv1.SignJWTRequest{Claims: "e30"}); err != nil {
		t.Fatal(err)
	}
}

func TestSignFailsUnavailableWhenOpenBaoGoesDown(t *testing.T) {
	f := newFixture(t, time.Hour)
	f.server.Close()
	_, err := f.signer().Sign(context.Background(), &externaljwtv1.SignJWTRequest{Claims: "e30"})
	if status.Code(err) != codes.Unavailable {
		t.Errorf("Sign = %v, want Unavailable", err)
	}
}

func TestCacheFollowsRotation(t *testing.T) {
	f := newFixture(t, time.Hour)
	path := f.withCache(t)
	f.fake.addVersion(t, f.clock.now())
	if err := f.keys.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	versions, _, err := loadCache(path, "transit", "kubernetes")
	if err != nil {
		t.Fatal(err)
	}
	if len(versions) != 2 || versions[0].version != 1 || versions[1].version != 2 {
		t.Fatalf("cached versions = %v", versions)
	}
	if !versions[1].created.Equal(f.clock.now()) {
		t.Errorf("creation time = %v, want %v", versions[1].created, f.clock.now())
	}
}

// Without a cache, as on the very first start, there is nothing to verify
// tokens with, so the signer waits for OpenBao
func TestWaitsForOpenBaoWithoutCache(t *testing.T) {
	f := newFixture(t, time.Hour)
	f.keys.cache = filepath.Join(t.TempDir(), "keys.json")
	f.server.Close()
	err := initialize(t, f.restarted())
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("initialize = %v, want it to wait until the deadline", err)
	}
	if _, err := os.Stat(f.keys.cache); !errors.Is(err, fs.ErrNotExist) {
		t.Errorf("cache: %v", err)
	}
}

func TestIgnoresCacheOfAnotherKey(t *testing.T) {
	f := newFixture(t, time.Hour)
	path := f.withCache(t)
	if _, _, err := loadCache(path, "transit", "other"); err == nil {
		t.Error("loaded the cache of another key")
	}
	if _, _, err := loadCache(path, "other-transit", "kubernetes"); err == nil {
		t.Error("loaded the cache of another mount")
	}
}

func TestIgnoresCorruptCache(t *testing.T) {
	path := filepath.Join(t.TempDir(), "keys.json")
	for _, content := range []string{
		"",
		"{",
		`{"mount":"transit","key":"kubernetes","versions":[]}`,
		`{"mount":"transit","key":"kubernetes","versions":[{"version":1,"pkix":"AAAA"}]}`,
	} {
		if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, _, err := loadCache(path, "transit", "kubernetes"); err == nil {
			t.Errorf("loaded %q", content)
		}
	}
}
