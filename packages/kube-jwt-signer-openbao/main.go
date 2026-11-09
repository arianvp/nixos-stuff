// Command kube-jwt-signer-openbao is an external service account token signer
// for kube-apiserver (--service-account-signing-endpoint) that signs with an
// ECDSA key in OpenBao's transit secrets engine.
//
// Every API server signs with the same key, so a token issued by any of them
// is accepted by all of them and no signing key is ever on a node. It
// authenticates to OpenBao with TLS certificate auth, and reads its
// certificate, key and CA bundle from files on every TLS handshake, so that it
// keeps working when they are rotated (e.g. X509-SVIDs kept by spiffe-helper).
//
// OpenBao rotates the key (auto_rotate_period). Every version it reports stays
// trusted, so tokens outlive the version that signed them, and a new version
// only starts signing once it is publishDelay old, by which time every signer
// has fetched it.
//
// With -cache, it keeps the public keys it read last on disk. If it starts
// while OpenBao is unreachable, it serves those, so that kube-apiserver starts
// and verifies tokens, and fails to sign with codes.Unavailable until it
// reaches OpenBao. Without a cache it waits for OpenBao.
package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"slices"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"
	externaljwtv1 "k8s.io/externaljwt/apis/v1"
)

const refreshInterval = 30 * time.Second

// retryInterval is how often the first read of the key is retried, while
// OpenBao comes up and is given the key and the cert auth role
const retryInterval = 5 * time.Second

// publishDelay is how long a key version exists before it signs. OpenBao
// reports when it was created, so every signer starts using it at the same
// time, after they have all fetched it.
const publishDelay = 2 * refreshInterval

type keyVersion struct {
	version int
	created time.Time
	kid     string
	pkix    []byte
	header  string // base64url encoded, as kube-apiserver wants it
}

func newKeyVersion(version int, created time.Time, publicKey string) (*keyVersion, error) {
	block, _ := pem.Decode([]byte(publicKey))
	if block == nil {
		return nil, errors.New("no PEM block in public key")
	}
	return newKeyVersionPKIX(version, created, block.Bytes)
}

func newKeyVersionPKIX(version int, created time.Time, der []byte) (*keyVersion, error) {
	pub, err := x509.ParsePKIXPublicKey(der)
	if err != nil {
		return nil, err
	}
	ec, ok := pub.(*ecdsa.PublicKey)
	if !ok || ec.Curve != elliptic.P256() {
		return nil, errors.New("not a P-256 key; the transit key must be ecdsa-p256")
	}
	sum := sha256.Sum256(der)
	kid := base64.RawURLEncoding.EncodeToString(sum[:])
	header, err := json.Marshal(map[string]string{"alg": "ES256", "kid": kid, "typ": "JWT"})
	if err != nil {
		return nil, err
	}
	return &keyVersion{
		version: version,
		created: created,
		kid:     kid,
		pkix:    der,
		header:  base64.RawURLEncoding.EncodeToString(header),
	}, nil
}

// keyset is the transit key as OpenBao last reported it
type keyset struct {
	bao   *openbao
	mount string
	key   string
	now   func() time.Time
	// cache is where the public keys are kept across restarts, so that the
	// API server can verify tokens while OpenBao is unreachable; none if empty
	cache string

	mu       sync.RWMutex
	versions []*keyVersion // oldest first
	fetched  time.Time
	// live is set once this process has read the key from OpenBao
	live bool

	// saved is what the cache holds. Only initialize and keepRefreshing use
	// it, one after the other.
	saved []*keyVersion
}

func (k *keyset) refresh(ctx context.Context) error {
	var resp struct {
		Data struct {
			Keys map[string]struct {
				PublicKey    string    `json:"public_key"`
				CreationTime time.Time `json:"creation_time"`
			} `json:"keys"`
		} `json:"data"`
	}
	if err := k.bao.call(ctx, http.MethodGet, k.mount+"/keys/"+k.key, nil, &resp); err != nil {
		return err
	}
	var versions []*keyVersion
	for raw, data := range resp.Data.Keys {
		version, err := strconv.Atoi(raw)
		if err != nil {
			return fmt.Errorf("key version %q: %w", raw, err)
		}
		v, err := newKeyVersion(version, data.CreationTime, data.PublicKey)
		if err != nil {
			return fmt.Errorf("key version %d: %w", version, err)
		}
		versions = append(versions, v)
	}
	if len(versions) == 0 {
		return fmt.Errorf("%s/keys/%s has no versions", k.mount, k.key)
	}
	slices.SortFunc(versions, func(a, b *keyVersion) int { return a.version - b.version })

	k.mu.Lock()
	k.versions = versions
	k.fetched = k.now()
	k.live = true
	fetched := k.fetched
	k.mu.Unlock()

	if k.cache != "" && !sameVersions(k.saved, versions) {
		if err := saveCache(k.cache, k.mount, k.key, versions, fetched); err != nil {
			slog.Warn("saving the keys", "path", k.cache, "error", err)
		} else {
			k.saved = versions
		}
	}
	return nil
}

func sameVersions(a, b []*keyVersion) bool {
	return slices.EqualFunc(a, b, func(x, y *keyVersion) bool {
		return x.version == y.version && x.kid == y.kid && x.created.Equal(y.created)
	})
}

// load reads the keys that were last read from OpenBao from the cache
func (k *keyset) load() error {
	versions, fetched, err := loadCache(k.cache, k.mount, k.key)
	if err != nil {
		return err
	}
	k.saved = versions
	k.mu.Lock()
	defer k.mu.Unlock()
	k.versions = versions
	k.fetched = fetched
	return nil
}

func (k *keyset) isLive() bool {
	k.mu.RLock()
	defer k.mu.RUnlock()
	return k.live
}

// initialize reads the keys from OpenBao. If OpenBao cannot be reached, it
// falls back to the cache, and without one it keeps trying: kube-apiserver
// does not start without keys, so rather than failing and taking the API
// server's start job down with us, we keep starting until OpenBao has the key
// and the cert auth role.
func (k *keyset) initialize(ctx context.Context) error {
	err := k.refresh(ctx)
	if err == nil {
		return nil
	}
	if k.cache != "" {
		cacheErr := k.load()
		if cacheErr == nil {
			slog.Warn("reading the key, serving the cached public keys until OpenBao answers", "mount", k.mount, "key", k.key, "error", err)
			return nil
		}
		if !errors.Is(cacheErr, fs.ErrNotExist) {
			slog.Warn("reading the cached keys", "path", k.cache, "error", cacheErr)
		}
	}
	for {
		slog.Warn("reading the key, retrying", "mount", k.mount, "key", k.key, "error", err)
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(retryInterval):
		}
		if err = k.refresh(ctx); err == nil {
			return nil
		}
	}
}

// keepRefreshing rereads the keys, more often while it has not reached
// OpenBao yet
func (k *keyset) keepRefreshing(ctx context.Context) {
	for {
		interval := refreshInterval
		if !k.isLive() {
			interval = retryInterval
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(interval):
		}
		if err := k.refresh(ctx); err != nil {
			slog.Warn("refreshing keys", "error", err)
		}
	}
}

// signing is the newest version that has been published long enough, or the
// oldest one when the key is younger than that.
func (k *keyset) signing() *keyVersion {
	k.mu.RLock()
	defer k.mu.RUnlock()
	cutoff := k.now().Add(-publishDelay)
	for i := len(k.versions) - 1; i >= 0; i-- {
		if k.versions[i].created.Before(cutoff) {
			return k.versions[i]
		}
	}
	return k.versions[0]
}

func (k *keyset) all() ([]*keyVersion, time.Time) {
	k.mu.RLock()
	defer k.mu.RUnlock()
	return k.versions, k.fetched
}

func (k *keyset) sign(ctx context.Context, version int, input string) (string, error) {
	var resp struct {
		Data struct {
			Signature string `json:"signature"`
		} `json:"data"`
	}
	body := map[string]any{
		"input":                base64.StdEncoding.EncodeToString([]byte(input)),
		"hash_algorithm":       "sha2-256",
		"marshaling_algorithm": "jws",
		"key_version":          version,
	}
	if err := k.bao.call(ctx, http.MethodPost, k.mount+"/sign/"+k.key, body, &resp); err != nil {
		return "", err
	}
	return jwsSignature(resp.Data.Signature)
}

// jwsSignature takes the signature out of transit's vault:v<n>:<signature>.
// The jws marshaling algorithm gives the fixed-size R || S encoding JWS uses
// (RFC 7518 section 3.4), in the URL alphabet; standard base64 is accepted
// too, as the alphabet is not part of the API.
func jwsSignature(signature string) (string, error) {
	parts := strings.SplitN(signature, ":", 3)
	if len(parts) != 3 || parts[0] != "vault" {
		return "", fmt.Errorf("malformed signature %q", signature)
	}
	raw, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		if raw, err = base64.StdEncoding.DecodeString(parts[2]); err != nil {
			return "", fmt.Errorf("decoding signature: %w", err)
		}
	}
	if len(raw) != 64 {
		return "", fmt.Errorf("signature is %d bytes, want 64", len(raw))
	}
	return base64.RawURLEncoding.EncodeToString(raw), nil
}

type signer struct {
	externaljwtv1.UnimplementedExternalJWTSignerServer

	keys      *keyset
	maxExpiry time.Duration
}

func (s *signer) Sign(ctx context.Context, req *externaljwtv1.SignJWTRequest) (*externaljwtv1.SignJWTResponse, error) {
	if !s.keys.isLive() {
		return nil, status.Error(codes.Unavailable, "OpenBao has not been reached yet; only the cached public keys are known")
	}
	key := s.keys.signing()
	signature, err := s.keys.sign(ctx, key.version, key.header+"."+req.Claims)
	if err != nil {
		return nil, status.Errorf(codes.Unavailable, "signing with OpenBao: %v", err)
	}
	return &externaljwtv1.SignJWTResponse{Header: key.header, Signature: signature}, nil
}

func (s *signer) FetchKeys(context.Context, *externaljwtv1.FetchKeysRequest) (*externaljwtv1.FetchKeysResponse, error) {
	versions, fetched := s.keys.all()
	keys := make([]*externaljwtv1.Key, 0, len(versions))
	for _, v := range versions {
		keys = append(keys, &externaljwtv1.Key{KeyId: v.kid, Key: v.pkix})
	}
	return &externaljwtv1.FetchKeysResponse{
		Keys:               keys,
		DataTimestamp:      timestamppb.New(fetched),
		RefreshHintSeconds: int64(refreshInterval / time.Second),
	}, nil
}

func (s *signer) Metadata(context.Context, *externaljwtv1.MetadataRequest) (*externaljwtv1.MetadataResponse, error) {
	return &externaljwtv1.MetadataResponse{MaxTokenExpirationSeconds: int64(s.maxExpiry / time.Second)}, nil
}

func notifyReady() {
	addr := os.Getenv("NOTIFY_SOCKET")
	if addr == "" {
		return
	}
	conn, err := net.DialUnix("unixgram", nil, &net.UnixAddr{Name: addr, Net: "unixgram"})
	if err != nil {
		slog.Warn("notifying systemd", "error", err)
		return
	}
	defer conn.Close()
	_, _ = conn.Write([]byte("READY=1"))
}

func run() error {
	var (
		socket    = flag.String("socket", "/run/kube-jwt-signer-openbao/signer.sock", "Unix socket kube-apiserver connects to")
		address   = flag.String("address", "", "URL of OpenBao")
		mount     = flag.String("transit-mount", "transit", "Path of the transit secrets engine")
		key       = flag.String("key", "kubernetes", "Name of the transit key, which must be of type ecdsa-p256")
		authMount = flag.String("auth-mount", "cert", "Path of the cert auth method")
		role      = flag.String("role", "", "Cert auth role to log in with; any matching role if empty")
		certFile  = flag.String("cert-file", "", "Client certificate, followed by its intermediates")
		keyFile   = flag.String("key-file", "", "Client key")
		caFile    = flag.String("ca-file", "", "CA certificates to verify OpenBao with")
		maxExpiry = flag.Duration("max-token-expiration", 365*24*time.Hour, "Maximum lifetime of the tokens kube-apiserver may request")
		timeout   = flag.Duration("timeout", 10*time.Second, "Timeout of requests to OpenBao")
		cache     = flag.String("cache", "", "File to keep the public keys in, to verify tokens with while OpenBao is unreachable")
	)
	flag.Parse()
	if *address == "" || *certFile == "" || *keyFile == "" || *caFile == "" {
		return errors.New("-address, -cert-file, -key-file and -ca-file are required")
	}

	keys := &keyset{
		bao: &openbao{
			address:   *address,
			authMount: *authMount,
			role:      *role,
			http: &http.Client{
				Timeout:   *timeout,
				Transport: &http.Transport{TLSClientConfig: newTLSConfig(*certFile, *keyFile, *caFile)},
			},
		},
		mount: *mount,
		key:   *key,
		now:   time.Now,
		cache: *cache,
	}
	s := &signer{keys: keys, maxExpiry: *maxExpiry}

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	if err := keys.initialize(ctx); err != nil {
		if ctx.Err() != nil {
			return nil
		}
		return err
	}
	go keys.keepRefreshing(ctx)

	_ = os.Remove(*socket)
	lis, err := net.Listen("unix", *socket)
	if err != nil {
		return err
	}
	server := grpc.NewServer(grpc.ConnectionTimeout(*timeout))
	externaljwtv1.RegisterExternalJWTSignerServer(server, s)
	go func() {
		<-ctx.Done()
		server.GracefulStop()
	}()

	slog.Info("serving", "socket", *socket, "address", *address, "key", *key, "kid", keys.signing().kid)
	notifyReady()
	return server.Serve(lis)
}

func main() {
	if err := run(); err != nil {
		slog.Error("exiting", "error", err)
		os.Exit(1)
	}
}
