// Command kube-jwt-signer is an external service account token signer for
// kube-apiserver (--service-account-signing-endpoint) that lets every API
// server keep its own signing key.
//
// It signs with keys that never leave the node and rotate periodically, and
// trusts the public keys of its peers, which it fetches from them over mutual
// TLS with X509-SVIDs from the SPIFFE Workload API. A token issued by any API
// server in the cluster is thus accepted by all of them, without sharing
// private keys.
package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"maps"
	"net"
	"net/http"
	"os"
	"os/signal"
	"slices"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/spiffe/go-spiffe/v2/spiffeid"
	"github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
	"github.com/spiffe/go-spiffe/v2/workloadapi"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
	externaljwtv1 "k8s.io/externaljwt/apis/v1"
)

const refreshInterval = 30 * time.Second

type peer struct {
	id  spiffeid.ID
	url string
}

type peerFlag []peer

func (p *peerFlag) String() string { return fmt.Sprint(*p) }

func (p *peerFlag) Set(value string) error {
	rawID, url, ok := strings.Cut(value, ",")
	if !ok {
		return errors.New("expected SPIFFE-ID,URL")
	}
	id, err := spiffeid.FromString(rawID)
	if err != nil {
		return err
	}
	*p = append(*p, peer{id: id, url: url})
	return nil
}

// publicKey is how keys travel between peers and to kube-apiserver
type publicKey struct {
	ID   string `json:"kid"`
	PKIX []byte `json:"pkix"`
}

type signer struct {
	externaljwtv1.UnimplementedExternalJWTSignerServer

	keys       *keyring
	maxExpiry  time.Duration
	mu         sync.Mutex
	peerKeys   map[string][]publicKey // by peer SPIFFE ID
	lastUpdate time.Time
}

func newSigner(keys *keyring, maxExpiry time.Duration) *signer {
	return &signer{
		keys:       keys,
		maxExpiry:  maxExpiry,
		peerKeys:   map[string][]publicKey{},
		lastUpdate: time.Now(),
	}
}

func (s *signer) Sign(_ context.Context, req *externaljwtv1.SignJWTRequest) (*externaljwtv1.SignJWTResponse, error) {
	key := s.keys.signing()
	digest := sha256.Sum256([]byte(key.header + "." + req.Claims))
	r, sv, err := ecdsa.Sign(rand.Reader, key.priv, digest[:])
	if err != nil {
		return nil, err
	}
	// JWS uses the fixed-size R || S encoding, not ASN.1 (RFC 7518 section 3.4)
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	sv.FillBytes(sig[32:])
	return &externaljwtv1.SignJWTResponse{
		Header:    key.header,
		Signature: base64.RawURLEncoding.EncodeToString(sig),
	}, nil
}

func (s *signer) FetchKeys(context.Context, *externaljwtv1.FetchKeysRequest) (*externaljwtv1.FetchKeysResponse, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var keys []*externaljwtv1.Key
	seen := map[string]bool{}
	sets := [][]publicKey{s.keys.publicKeys()}
	for _, id := range slices.Sorted(maps.Keys(s.peerKeys)) {
		sets = append(sets, s.peerKeys[id])
	}
	for _, set := range sets {
		for _, k := range set {
			if !seen[k.ID] {
				seen[k.ID] = true
				keys = append(keys, &externaljwtv1.Key{KeyId: k.ID, Key: k.PKIX})
			}
		}
	}
	return &externaljwtv1.FetchKeysResponse{
		Keys:               keys,
		DataTimestamp:      timestamppb.New(s.lastUpdate),
		RefreshHintSeconds: int64(refreshInterval / time.Second),
	}, nil
}

func (s *signer) Metadata(context.Context, *externaljwtv1.MetadataRequest) (*externaljwtv1.MetadataResponse, error) {
	return &externaljwtv1.MetadataResponse{MaxTokenExpirationSeconds: int64(s.maxExpiry / time.Second)}, nil
}

func (s *signer) setPeerKeys(id spiffeid.ID, keys []publicKey) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if !slices.EqualFunc(s.peerKeys[id.String()], keys, func(a, b publicKey) bool {
		return a.ID == b.ID && string(a.PKIX) == string(b.PKIX)
	}) {
		s.peerKeys[id.String()] = keys
		s.lastUpdate = time.Now()
	}
}

// validate checks that a key a peer sent is usable and named by its hash, so
// that a peer cannot claim another key's ID.
func validate(k publicKey) error {
	pub, err := x509.ParsePKIXPublicKey(k.PKIX)
	if err != nil {
		return err
	}
	if _, ok := pub.(*ecdsa.PublicKey); !ok {
		return errors.New("not an ECDSA key")
	}
	sum := sha256.Sum256(k.PKIX)
	if k.ID != base64.RawURLEncoding.EncodeToString(sum[:]) {
		return errors.New("key ID does not match key")
	}
	return nil
}

func fetchPeer(ctx context.Context, source *workloadapi.X509Source, p peer) ([]publicKey, error) {
	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: tlsconfig.MTLSClientConfig(source, source, tlsconfig.AuthorizeID(p.id)),
		},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimSuffix(p.url, "/")+"/keys", nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status %s", resp.Status)
	}
	var keys []publicKey
	if err := json.NewDecoder(resp.Body).Decode(&keys); err != nil {
		return nil, err
	}
	for _, k := range keys {
		if err := validate(k); err != nil {
			return nil, fmt.Errorf("key %q: %w", k.ID, err)
		}
	}
	return keys, nil
}

// syncPeers keeps the keys of each peer. Keys of unreachable peers are kept,
// so tokens they issued stay valid while they are down.
func (s *signer) syncPeers(ctx context.Context, source *workloadapi.X509Source, peers []peer) {
	ticker := time.NewTicker(refreshInterval)
	defer ticker.Stop()
	for {
		for _, p := range peers {
			keys, err := fetchPeer(ctx, source, p)
			if err != nil {
				slog.Warn("fetching keys from peer", "peer", p.id, "url", p.url, "error", err)
				continue
			}
			s.setPeerKeys(p.id, keys)
		}
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}

func (s *signer) servePeers(ctx context.Context, source *workloadapi.X509Source, addr string, td spiffeid.TrustDomain) error {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /keys", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(s.keys.publicKeys())
	})
	server := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
		TLSConfig:         tlsconfig.MTLSServerConfig(source, source, tlsconfig.AuthorizeMemberOf(td)),
	}
	go func() {
		<-ctx.Done()
		_ = server.Close()
	}()
	if err := server.ListenAndServeTLS("", ""); !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
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
		socket    = flag.String("socket", "/run/kube-jwt-signer/signer.sock", "Unix socket kube-apiserver connects to")
		keyDir    = flag.String("key-dir", "/var/lib/kube-jwt-signer", "Directory of the signing keys; created if needed")
		rotation  = flag.Duration("rotation-period", 30*24*time.Hour, "How long a key signs before the next one takes over; 0 disables rotation")
		listen    = flag.String("listen", "", "Address to serve the public keys to peers on, e.g. [::]:10260")
		maxExpiry = flag.Duration("max-token-expiration", 365*24*time.Hour, "Maximum lifetime of the tokens kube-apiserver may request")
		peers     peerFlag
	)
	flag.Var(&peers, "peer", "SPIFFE-ID,URL of a peer whose keys to trust; repeatable")
	flag.Parse()

	if *rotation != 0 && *rotation <= publishDelay {
		return fmt.Errorf("-rotation-period must be longer than %s", publishDelay)
	}
	if err := os.MkdirAll(*keyDir, 0o700); err != nil {
		return err
	}
	keys := &keyring{dir: *keyDir, rotation: *rotation, retention: *maxExpiry, now: time.Now}
	if err := keys.load(); err != nil {
		return fmt.Errorf("loading signing keys: %w", err)
	}
	if err := keys.maintain(); err != nil {
		return fmt.Errorf("creating signing key: %w", err)
	}
	s := newSigner(keys, *maxExpiry)

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	go func() {
		ticker := time.NewTicker(time.Minute)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if err := keys.maintain(); err != nil {
					slog.Error("rotating signing keys", "error", err)
				}
			}
		}
	}()

	_ = os.Remove(*socket)
	lis, err := net.Listen("unix", *socket)
	if err != nil {
		return err
	}
	server := grpc.NewServer()
	externaljwtv1.RegisterExternalJWTSignerServer(server, s)
	go func() {
		<-ctx.Done()
		server.GracefulStop()
	}()

	errs := make(chan error, 2)
	if *listen != "" || len(peers) > 0 {
		// Signing works without SPIRE; only exchanging keys waits for an SVID
		go func() {
			source, err := workloadapi.NewX509Source(ctx)
			if err != nil {
				errs <- fmt.Errorf("connecting to the Workload API: %w", err)
				return
			}
			defer source.Close()
			svid, err := source.GetX509SVID()
			if err != nil {
				errs <- err
				return
			}
			slog.Info("got X509-SVID", "id", svid.ID)
			go s.syncPeers(ctx, source, peers)
			if *listen != "" {
				errs <- s.servePeers(ctx, source, *listen, svid.ID.TrustDomain())
			} else {
				<-ctx.Done()
			}
		}()
	}

	slog.Info("serving", "socket", *socket, "kid", keys.signing().pub.ID, "peers", len(peers))
	notifyReady()
	go func() { errs <- server.Serve(lis) }()
	select {
	case err := <-errs:
		return err
	case <-ctx.Done():
		return nil
	}
}

func main() {
	if err := run(); err != nil {
		slog.Error("exiting", "error", err)
		os.Exit(1)
	}
}
