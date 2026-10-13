package main

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"k8s.io/kms/pkg/service"
)

type ca struct {
	cert *x509.Certificate
	key  *ecdsa.PrivateKey
	pem  []byte
}

func newCA(t *testing.T) *ca {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	tmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "test CA"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign,
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	cert, _ := x509.ParseCertificate(der)
	return &ca{cert: cert, key: key, pem: pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})}
}

// issue returns a PEM certificate and key for a client (with a SPIFFE ID) or
// a server (for 127.0.0.1)
func (c *ca) issue(t *testing.T, spiffeID string) (certPEM, keyPEM []byte) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	serial, _ := rand.Int(rand.Reader, big.NewInt(1<<62))
	tmpl := &x509.Certificate{
		SerialNumber: serial,
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth, x509.ExtKeyUsageServerAuth},
		KeyUsage:     x509.KeyUsageDigitalSignature,
	}
	if spiffeID != "" {
		uri, _ := url.Parse(spiffeID)
		tmpl.URIs = []*url.URL{uri}
	} else {
		tmpl.IPAddresses = []net.IP{net.ParseIP("127.0.0.1")}
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, c.cert, &key.PublicKey, c.key)
	if err != nil {
		t.Fatal(err)
	}
	keyDER, _ := x509.MarshalPKCS8PrivateKey(key)
	return pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}),
		pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: keyDER})
}

// fakeOpenBao implements just enough of cert auth and transit
type fakeOpenBao struct {
	mu         sync.Mutex
	version    int
	tokens     map[string]bool
	logins     int
	clientIDs  []string
	tokenCount int
}

func (f *fakeOpenBao) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	reply := func(v any) { _ = json.NewEncoder(w).Encode(v) }
	var body map[string]string
	_ = json.NewDecoder(r.Body).Decode(&body)

	if r.URL.Path == "/v1/auth/cert/login" {
		uris := r.TLS.PeerCertificates[0].URIs
		f.clientIDs = append(f.clientIDs, uris[0].String())
		f.logins++
		f.tokenCount++
		token := "token-" + strconv.Itoa(f.tokenCount)
		f.tokens[token] = true
		reply(map[string]any{"auth": map[string]any{"client_token": token, "lease_duration": 3600}})
		return
	}
	if !f.tokens[r.Header.Get("X-Vault-Token")] {
		http.Error(w, `{"errors":["permission denied"]}`, http.StatusForbidden)
		return
	}
	switch r.URL.Path {
	case "/v1/transit/keys/kubernetes":
		reply(map[string]any{"data": map[string]any{"latest_version": f.version}})
	case "/v1/transit/encrypt/kubernetes":
		ciphertext := "vault:v" + strconv.Itoa(f.version) + ":" + reverse(body["plaintext"])
		reply(map[string]any{"data": map[string]any{"ciphertext": ciphertext, "key_version": f.version}})
	case "/v1/transit/decrypt/kubernetes":
		parts := strings.SplitN(body["ciphertext"], ":", 3)
		reply(map[string]any{"data": map[string]any{"plaintext": reverse(parts[2])}})
	default:
		http.NotFound(w, r)
	}
}

func reverse(s string) string {
	b := []byte(s)
	for i, j := 0, len(b)-1; i < j; i, j = i+1, j-1 {
		b[i], b[j] = b[j], b[i]
	}
	return string(b)
}

type fixture struct {
	fake    *fakeOpenBao
	plugin  *plugin
	dir     string
	ca      *ca
	server  *httptest.Server
	clients *http.Transport
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	authority := newCA(t)
	fake := &fakeOpenBao{version: 1, tokens: map[string]bool{}}
	server := httptest.NewUnstartedServer(fake)
	serverCert, serverKey := authority.issue(t, "")
	pair, err := tls.X509KeyPair(serverCert, serverKey)
	if err != nil {
		t.Fatal(err)
	}
	pool := x509.NewCertPool()
	pool.AddCert(authority.cert)
	server.TLS = &tls.Config{Certificates: []tls.Certificate{pair}, ClientAuth: tls.RequireAndVerifyClientCert, ClientCAs: pool}
	server.StartTLS()
	t.Cleanup(server.Close)

	dir := t.TempDir()
	f := &fixture{fake: fake, dir: dir, ca: authority, server: server}
	f.writeClient(t, authority, "spiffe://example.org/k8s/kms/a")
	if err := os.WriteFile(filepath.Join(dir, "bundle.pem"), authority.pem, 0o644); err != nil {
		t.Fatal(err)
	}
	f.clients = &http.Transport{TLSClientConfig: newTLSConfig(
		filepath.Join(dir, "svid.pem"), filepath.Join(dir, "svid.key"), filepath.Join(dir, "bundle.pem"),
	)}
	f.plugin = &plugin{
		bao:   &openbao{address: server.URL, authMount: "cert", http: &http.Client{Transport: f.clients}},
		mount: "transit",
		key:   "kubernetes",
	}
	return f
}

func (f *fixture) writeClient(t *testing.T, authority *ca, spiffeID string) {
	t.Helper()
	cert, key := authority.issue(t, spiffeID)
	if err := os.WriteFile(filepath.Join(f.dir, "svid.pem"), cert, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(f.dir, "svid.key"), key, 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestRoundTrip(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	plaintext := []byte("very secret")

	encrypted, err := f.plugin.Encrypt(ctx, "uid", plaintext)
	if err != nil {
		t.Fatal(err)
	}
	if encrypted.KeyID != "kubernetes:1" {
		t.Errorf("KeyID = %q", encrypted.KeyID)
	}
	if bytes.Contains(encrypted.Ciphertext, plaintext) || bytes.Contains(encrypted.Ciphertext, []byte(base64.StdEncoding.EncodeToString(plaintext))) {
		t.Errorf("ciphertext %q contains the plaintext", encrypted.Ciphertext)
	}
	decrypted, err := f.plugin.Decrypt(ctx, "uid", &service.DecryptRequest{Ciphertext: encrypted.Ciphertext, KeyID: encrypted.KeyID})
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(decrypted, plaintext) {
		t.Errorf("decrypted %q", decrypted)
	}
	if f.fake.logins != 1 {
		t.Errorf("%d logins, want the token to be reused", f.fake.logins)
	}
	if f.fake.clientIDs[0] != "spiffe://example.org/k8s/kms/a" {
		t.Errorf("logged in as %v", f.fake.clientIDs)
	}
}

func TestStatusFollowsKeyRotation(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	status, err := f.plugin.Status(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if status.Version != "v2" || status.Healthz != "ok" || status.KeyID != "kubernetes:1" {
		t.Errorf("status = %+v", status)
	}
	f.fake.version = 2
	status, err = f.plugin.Status(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if status.KeyID != "kubernetes:2" {
		t.Errorf("KeyID after rotation = %q", status.KeyID)
	}
}

func TestLogsInAgainWhenTheTokenIsRevoked(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	if _, err := f.plugin.Status(ctx); err != nil {
		t.Fatal(err)
	}
	f.fake.tokens = map[string]bool{}
	if _, err := f.plugin.Status(ctx); err != nil {
		t.Fatal(err)
	}
	if f.fake.logins != 2 {
		t.Errorf("%d logins, want 2", f.fake.logins)
	}
}

func TestPicksUpRotatedFiles(t *testing.T) {
	f := newFixture(t)
	ctx := context.Background()
	if _, err := f.plugin.Status(ctx); err != nil {
		t.Fatal(err)
	}
	f.writeClient(t, f.ca, "spiffe://example.org/k8s/kms/rotated")
	f.clients.CloseIdleConnections()
	f.fake.tokens = map[string]bool{}
	if _, err := f.plugin.Status(ctx); err != nil {
		t.Fatal(err)
	}
	if got := f.fake.clientIDs[len(f.fake.clientIDs)-1]; got != "spiffe://example.org/k8s/kms/rotated" {
		t.Errorf("logged in as %s after rotation", got)
	}
}

func TestRejectsUntrustedServer(t *testing.T) {
	f := newFixture(t)
	if err := os.WriteFile(filepath.Join(f.dir, "bundle.pem"), newCA(t).pem, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := f.plugin.Status(context.Background()); err == nil || !strings.Contains(err.Error(), "certificate") {
		t.Errorf("err = %v, want a certificate verification error", err)
	}
}
