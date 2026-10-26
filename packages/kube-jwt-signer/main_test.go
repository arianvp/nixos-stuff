package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/spiffe/go-spiffe/v2/spiffeid"
	externaljwtv1 "k8s.io/externaljwt/apis/v1"
)

type clock struct{ t time.Time }

func (c *clock) now() time.Time          { return c.t }
func (c *clock) advance(d time.Duration) { c.t = c.t.Add(d) }

func newTestKeyring(t *testing.T, c *clock, rotation, retention time.Duration) *keyring {
	t.Helper()
	k := &keyring{dir: t.TempDir(), rotation: rotation, retention: retention, now: c.now}
	if err := k.load(); err != nil {
		t.Fatal(err)
	}
	if err := k.maintain(); err != nil {
		t.Fatal(err)
	}
	return k
}

func newTestSigner(t *testing.T) *signer {
	t.Helper()
	return newSigner(newTestKeyring(t, &clock{time.Unix(1e9, 0)}, 0, time.Hour), time.Hour)
}

func kids(keys []publicKey) []string {
	var ids []string
	for _, k := range keys {
		ids = append(ids, k.ID)
	}
	return ids
}

func TestSignVerifies(t *testing.T) {
	s := newTestSigner(t)
	claims := base64.RawURLEncoding.EncodeToString([]byte(`{"sub":"system:serviceaccount:default:default"}`))
	resp, err := s.Sign(context.Background(), &externaljwtv1.SignJWTRequest{Claims: claims})
	if err != nil {
		t.Fatal(err)
	}

	headerJSON, err := base64.RawURLEncoding.DecodeString(resp.Header)
	if err != nil {
		t.Fatal(err)
	}
	var header map[string]string
	if err := json.Unmarshal(headerJSON, &header); err != nil {
		t.Fatal(err)
	}
	own := s.keys.signing().pub
	if header["alg"] != "ES256" || header["typ"] != "JWT" || header["kid"] != own.ID || len(header) != 3 {
		t.Errorf("header = %v", header)
	}

	keys, err := s.FetchKeys(context.Background(), &externaljwtv1.FetchKeysRequest{})
	if err != nil {
		t.Fatal(err)
	}
	pub, err := x509.ParsePKIXPublicKey(keys.Keys[0].Key)
	if err != nil {
		t.Fatal(err)
	}
	sig, err := base64.RawURLEncoding.DecodeString(resp.Signature)
	if err != nil || len(sig) != 64 {
		t.Fatalf("signature %q: %v", resp.Signature, err)
	}
	digest := sha256.Sum256([]byte(resp.Header + "." + claims))
	r, sv := new(big.Int).SetBytes(sig[:32]), new(big.Int).SetBytes(sig[32:])
	if !ecdsa.Verify(pub.(*ecdsa.PublicKey), digest[:], r, sv) {
		t.Error("signature does not verify")
	}
}

func TestKeysPersist(t *testing.T) {
	c := &clock{time.Unix(1e9, 0)}
	a := newTestKeyring(t, c, time.Hour, time.Hour)
	b := &keyring{dir: a.dir, rotation: time.Hour, retention: time.Hour, now: c.now}
	if err := b.load(); err != nil {
		t.Fatal(err)
	}
	if err := b.maintain(); err != nil {
		t.Fatal(err)
	}
	if got, want := kids(b.publicKeys()), kids(a.publicKeys()); len(got) != 1 || got[0] != want[0] {
		t.Errorf("keys after reload = %v, want %v", got, want)
	}
}

func TestRotation(t *testing.T) {
	c := &clock{time.Unix(1e9, 0)}
	rotation, retention := 10*time.Minute, 30*time.Minute
	k := newTestKeyring(t, c, rotation, retention)
	first := k.signing().pub.ID

	// The next key is published ahead of time but does not sign yet
	c.advance(rotation - publishDelay)
	if err := k.maintain(); err != nil {
		t.Fatal(err)
	}
	keys := kids(k.publicKeys())
	if len(keys) != 2 || keys[0] != first {
		t.Fatalf("keys = %v", keys)
	}
	if got := k.signing().pub.ID; got != first {
		t.Errorf("signing with %s before it was published long enough", got)
	}

	c.advance(publishDelay)
	if got := k.signing().pub.ID; got != keys[1] {
		t.Errorf("signing with %s, want the new key %s", got, keys[1])
	}

	// The old key is trusted as long as tokens it signed may live
	c.advance(retention - time.Second)
	if err := k.maintain(); err != nil {
		t.Fatal(err)
	}
	if got := kids(k.publicKeys()); got[0] != first {
		t.Errorf("first key retired early: %v", got)
	}
	c.advance(time.Second)
	if err := k.maintain(); err != nil {
		t.Fatal(err)
	}
	for _, id := range kids(k.publicKeys()) {
		if id == first {
			t.Error("first key not retired")
		}
	}
	entries, err := os.ReadDir(k.dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != len(k.publicKeys()) {
		t.Errorf("%d key files for %d keys", len(entries), len(k.publicKeys()))
	}
}

func TestNoRotation(t *testing.T) {
	c := &clock{time.Unix(1e9, 0)}
	k := newTestKeyring(t, c, 0, time.Hour)
	c.advance(1000 * time.Hour)
	if err := k.maintain(); err != nil {
		t.Fatal(err)
	}
	if n := len(k.publicKeys()); n != 1 {
		t.Errorf("%d keys without rotation", n)
	}
}

func TestPeerKeys(t *testing.T) {
	s := newTestSigner(t)
	other := newTestSigner(t)
	own, theirs := s.keys.signing().pub, other.keys.signing().pub
	id := spiffeid.RequireFromString("spiffe://example.org/peer")

	if err := validate(theirs); err != nil {
		t.Fatal(err)
	}
	forged := theirs
	forged.ID = own.ID
	if err := validate(forged); err == nil || !strings.Contains(err.Error(), "does not match") {
		t.Errorf("forged key ID accepted: %v", err)
	}

	s.setPeerKeys(id, []publicKey{theirs})
	keys, err := s.FetchKeys(context.Background(), &externaljwtv1.FetchKeysRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if len(keys.Keys) != 2 || keys.Keys[0].KeyId != own.ID || keys.Keys[1].KeyId != theirs.ID {
		t.Errorf("keys = %v", keys.Keys)
	}
}
