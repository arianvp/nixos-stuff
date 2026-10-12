package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"
)

// publishDelay is how long a new key is published before it signs, so that
// every API server has fetched it by the time it sees tokens signed with it.
const publishDelay = 2 * refreshInterval

type signingKey struct {
	priv    *ecdsa.PrivateKey
	pub     publicKey
	header  string
	created time.Time
}

// keyring holds the signing keys of this signer, one file per key named
// after its creation time. A new key is created before the current one is
// rotation old; a superseded key stays trusted for retention, the longest
// lifetime of the tokens it signed.
type keyring struct {
	dir       string
	rotation  time.Duration // never rotate if 0
	retention time.Duration
	now       func() time.Time

	mu   sync.RWMutex
	keys []*signingKey // oldest first
}

func newSigningKey(priv *ecdsa.PrivateKey, created time.Time) (*signingKey, error) {
	der, err := x509.MarshalPKIXPublicKey(&priv.PublicKey)
	if err != nil {
		return nil, err
	}
	sum := sha256.Sum256(der)
	kid := base64.RawURLEncoding.EncodeToString(sum[:])
	header, err := json.Marshal(map[string]string{"alg": "ES256", "kid": kid, "typ": "JWT"})
	if err != nil {
		return nil, err
	}
	return &signingKey{
		priv:    priv,
		pub:     publicKey{ID: kid, PKIX: der},
		header:  base64.RawURLEncoding.EncodeToString(header),
		created: created,
	}, nil
}

func readKey(path string) (*ecdsa.PrivateKey, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	block, _ := pem.Decode(data)
	if block == nil {
		return nil, fmt.Errorf("%s: no PEM data", path)
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok || key.Curve != elliptic.P256() {
		return nil, fmt.Errorf("%s: not a P-256 ECDSA key", path)
	}
	return key, nil
}

func writeKey(path string, key *ecdsa.PrivateKey) error {
	der, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}), 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func (k *keyring) path(created time.Time) string {
	return filepath.Join(k.dir, strconv.FormatInt(created.Unix(), 10)+".pem")
}

func (k *keyring) load() error {
	entries, err := os.ReadDir(k.dir)
	if err != nil {
		return err
	}
	var keys []*signingKey
	for _, entry := range entries {
		seconds, err := strconv.ParseInt(strings.TrimSuffix(entry.Name(), ".pem"), 10, 64)
		if err != nil || !strings.HasSuffix(entry.Name(), ".pem") {
			continue
		}
		priv, err := readKey(filepath.Join(k.dir, entry.Name()))
		if err != nil {
			return err
		}
		key, err := newSigningKey(priv, time.Unix(seconds, 0))
		if err != nil {
			return err
		}
		keys = append(keys, key)
	}
	slices.SortFunc(keys, func(a, b *signingKey) int { return a.created.Compare(b.created) })
	k.mu.Lock()
	k.keys = keys
	k.mu.Unlock()
	return nil
}

// maintain creates the next key when it is due and removes retired keys
func (k *keyring) maintain() error {
	now := k.now().Truncate(time.Second)

	k.mu.RLock()
	keys := slices.Clone(k.keys)
	k.mu.RUnlock()

	if len(keys) == 0 || (k.rotation > 0 && now.Sub(keys[len(keys)-1].created) >= k.rotation-publishDelay) {
		priv, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		if err != nil {
			return err
		}
		key, err := newSigningKey(priv, now)
		if err != nil {
			return err
		}
		if err := writeKey(k.path(now), priv); err != nil {
			return err
		}
		slog.Info("created signing key", "kid", key.pub.ID)
		keys = append(keys, key)
	}

	// A key stops signing when its successor starts to
	for len(keys) > 1 && now.Sub(keys[1].created.Add(publishDelay)) >= k.retention {
		if err := os.Remove(k.path(keys[0].created)); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
		slog.Info("retired signing key", "kid", keys[0].pub.ID)
		keys = keys[1:]
	}

	k.mu.Lock()
	k.keys = keys
	k.mu.Unlock()
	return nil
}

// signing returns the newest key that has been published for long enough,
// or the oldest key while there is none.
func (k *keyring) signing() *signingKey {
	k.mu.RLock()
	defer k.mu.RUnlock()
	now := k.now()
	for _, key := range slices.Backward(k.keys) {
		if now.Sub(key.created) >= publishDelay {
			return key
		}
	}
	return k.keys[0]
}

func (k *keyring) publicKeys() []publicKey {
	k.mu.RLock()
	defer k.mu.RUnlock()
	keys := make([]publicKey, len(k.keys))
	for i, key := range k.keys {
		keys[i] = key.pub
	}
	return keys
}
