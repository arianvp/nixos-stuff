package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
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
	"sync"
	"testing"
	"time"

	externaljwtv1 "k8s.io/externaljwt/apis/v1"
)

type clock struct{ t time.Time }

func (c *clock) now() time.Time          { return c.t }
func (c *clock) advance(d time.Duration) { c.t = c.t.Add(d) }

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

// fakeOpenBao implements just enough of cert auth and of transit's ecdsa-p256
// sign and key read
type fakeOpenBao struct {
	mu         sync.Mutex
	keys       []*ecdsa.PrivateKey // version n is keys[n-1]
	created    []time.Time
	tokens     map[string]bool
	logins     int
	tokenCount int
	signed     []int // key versions that were asked to sign
}

func newFakeOpenBao(t *testing.T, created ...time.Time) *fakeOpenBao {
	t.Helper()
	f := &fakeOpenBao{tokens: map[string]bool{}}
	for _, at := range created {
		f.addVersion(t, at)
	}
	return f
}

func (f *fakeOpenBao) addVersion(t *testing.T, at time.Time) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	f.keys = append(f.keys, key)
	f.created = append(f.created, at)
}

func (f *fakeOpenBao) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	reply := func(v any) { _ = json.NewEncoder(w).Encode(v) }
	var body map[string]any
	_ = json.NewDecoder(r.Body).Decode(&body)

	if r.URL.Path == "/v1/auth/cert/login" {
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
		keys := map[string]any{}
		for i, key := range f.keys {
			der, err := x509.MarshalPKIXPublicKey(&key.PublicKey)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			keys[strconv.Itoa(i+1)] = map[string]any{
				"name":          "P-256",
				"creation_time": f.created[i].Format(time.RFC3339Nano),
				"public_key":    string(pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: der})),
			}
		}
		reply(map[string]any{"data": map[string]any{
			"type":           "ecdsa-p256",
			"latest_version": len(f.keys),
			"keys":           keys,
		}})
	case "/v1/transit/sign/kubernetes":
		version := int(body["key_version"].(float64))
		f.signed = append(f.signed, version)
		input, err := base64.StdEncoding.DecodeString(body["input"].(string))
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		digest := sha256.Sum256(input)
		rr, ss, err := ecdsa.Sign(rand.Reader, f.keys[version-1], digest[:])
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		sig := make([]byte, 64)
		rr.FillBytes(sig[:32])
		ss.FillBytes(sig[32:])
		reply(map[string]any{"data": map[string]any{
			"signature":   "vault:v" + strconv.Itoa(version) + ":" + base64.RawURLEncoding.EncodeToString(sig),
			"key_version": version,
		}})
	default:
		http.NotFound(w, r)
	}
}

type fixture struct {
	fake  *fakeOpenBao
	keys  *keyset
	clock *clock
}

// newFixture serves fake OpenBao over mutual TLS, with key versions created at
// the given times relative to the fixed clock.
func newFixture(t *testing.T, ages ...time.Duration) *fixture {
	t.Helper()
	c := &clock{time.Unix(1e9, 0)}
	authority := newCA(t)
	fake := newFakeOpenBao(t)
	for _, age := range ages {
		fake.addVersion(t, c.now().Add(-age))
	}

	server := httptest.NewUnstartedServer(fake)
	serverCert, serverKey := authority.issue(t, "")
	pair, err := tls.X509KeyPair(serverCert, serverKey)
	if err != nil {
		t.Fatal(err)
	}
	pool := x509.NewCertPool()
	pool.AddCert(authority.cert)
	server.TLS = &tls.Config{
		Certificates: []tls.Certificate{pair},
		ClientAuth:   tls.RequireAndVerifyClientCert,
		ClientCAs:    pool,
	}
	server.StartTLS()
	t.Cleanup(server.Close)

	dir := t.TempDir()
	cert, key := authority.issue(t, "spiffe://example.org/k8s/jwt-signer/a")
	for name, content := range map[string][]byte{
		"svid.pem":   cert,
		"svid.key":   key,
		"bundle.pem": authority.pem,
	} {
		if err := os.WriteFile(filepath.Join(dir, name), content, 0o600); err != nil {
			t.Fatal(err)
		}
	}

	f := &fixture{fake: fake, clock: c}
	f.keys = &keyset{
		bao: &openbao{
			address:   server.URL,
			authMount: "cert",
			http: &http.Client{Transport: &http.Transport{TLSClientConfig: newTLSConfig(
				filepath.Join(dir, "svid.pem"),
				filepath.Join(dir, "svid.key"),
				filepath.Join(dir, "bundle.pem"),
			)}},
		},
		mount: "transit",
		key:   "kubernetes",
		now:   c.now,
	}
	if err := f.keys.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	return f
}

func (f *fixture) signer() *signer {
	return &signer{keys: f.keys, maxExpiry: time.Hour}
}

func TestSignVerifies(t *testing.T) {
	f := newFixture(t, time.Hour)
	s := f.signer()
	ctx := context.Background()
	claims := base64.RawURLEncoding.EncodeToString([]byte(`{"sub":"system:serviceaccount:default:default"}`))

	resp, err := s.Sign(ctx, &externaljwtv1.SignJWTRequest{Claims: claims})
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
	kid := f.keys.signing().kid
	if header["alg"] != "ES256" || header["typ"] != "JWT" || header["kid"] != kid || len(header) != 3 {
		t.Errorf("header = %v", header)
	}

	fetched, err := s.FetchKeys(ctx, &externaljwtv1.FetchKeysRequest{})
	if err != nil {
		t.Fatal(err)
	}
	var der []byte
	for _, k := range fetched.Keys {
		if k.KeyId == kid {
			der = k.Key
		}
	}
	if der == nil {
		t.Fatalf("FetchKeys did not return the signing key %s", kid)
	}
	pub, err := x509.ParsePKIXPublicKey(der)
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

func TestFetchKeysReturnsEveryVersion(t *testing.T) {
	f := newFixture(t, 3*time.Hour, 2*time.Hour, time.Hour)
	fetched, err := f.signer().FetchKeys(context.Background(), &externaljwtv1.FetchKeysRequest{})
	if err != nil {
		t.Fatal(err)
	}
	if len(fetched.Keys) != 3 {
		t.Fatalf("%d keys, want 3", len(fetched.Keys))
	}
	versions, _ := f.keys.all()
	for i, v := range versions {
		if fetched.Keys[i].KeyId != v.kid {
			t.Errorf("key %d = %s, want %s", i, fetched.Keys[i].KeyId, v.kid)
		}
	}
	if fetched.RefreshHintSeconds != int64(refreshInterval/time.Second) {
		t.Errorf("refresh hint = %d", fetched.RefreshHintSeconds)
	}
}

// A version signs only once every signer has had the chance to fetch it, so
// that no API server sees a token signed by a key it does not know yet.
func TestNewVersionSignsAfterPublishDelay(t *testing.T) {
	f := newFixture(t, time.Hour)
	old := f.keys.signing()

	f.fake.addVersion(t, f.clock.now())
	if err := f.keys.refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	if got := f.keys.signing(); got.version != old.version {
		t.Errorf("signing with version %d before it was published long enough", got.version)
	}

	f.clock.advance(publishDelay + time.Second)
	if got := f.keys.signing(); got.version != 2 {
		t.Errorf("signing with version %d, want the new version 2", got.version)
	}

	if _, err := f.signer().Sign(context.Background(), &externaljwtv1.SignJWTRequest{Claims: "e30"}); err != nil {
		t.Fatal(err)
	}
	if got := f.fake.signed; len(got) != 1 || got[0] != 2 {
		t.Errorf("signed with versions %v, want [2]", got)
	}
}

// A key that was just created has no published version to fall back on
func TestFreshKeySignsImmediately(t *testing.T) {
	f := newFixture(t, 0)
	if got := f.keys.signing(); got.version != 1 {
		t.Errorf("signing version = %d, want 1", got.version)
	}
	if _, err := f.signer().Sign(context.Background(), &externaljwtv1.SignJWTRequest{Claims: "e30"}); err != nil {
		t.Fatal(err)
	}
}

func TestRejectsNonECDSAKey(t *testing.T) {
	if _, err := newKeyVersion(1, time.Now(), "not a PEM block"); err == nil {
		t.Error("accepted a key that is not PEM")
	}
	key, err := ecdsa.GenerateKey(elliptic.P521(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	der, err := x509.MarshalPKIXPublicKey(&key.PublicKey)
	if err != nil {
		t.Fatal(err)
	}
	encoded := string(pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: der}))
	if _, err := newKeyVersion(1, time.Now(), encoded); err == nil {
		t.Error("accepted a P-521 key")
	}
}

func TestLogsInAgainWhenTokenIsRevoked(t *testing.T) {
	f := newFixture(t, time.Hour)
	f.fake.mu.Lock()
	f.fake.tokens = map[string]bool{}
	logins := f.fake.logins
	f.fake.mu.Unlock()

	if _, err := f.signer().Sign(context.Background(), &externaljwtv1.SignJWTRequest{Claims: "e30"}); err != nil {
		t.Fatal(err)
	}
	f.fake.mu.Lock()
	defer f.fake.mu.Unlock()
	if f.fake.logins != logins+1 {
		t.Errorf("%d logins, want %d", f.fake.logins, logins+1)
	}
}

func TestJWSSignature(t *testing.T) {
	sig := make([]byte, 64)
	for i := range sig {
		sig[i] = byte(i)
	}
	want := base64.RawURLEncoding.EncodeToString(sig)
	for _, encoded := range []string{
		base64.RawURLEncoding.EncodeToString(sig),
		base64.StdEncoding.EncodeToString(sig),
	} {
		got, err := jwsSignature("vault:v3:" + encoded)
		if err != nil {
			t.Fatalf("%q: %v", encoded, err)
		}
		if got != want {
			t.Errorf("%q = %q, want %q", encoded, got, want)
		}
	}
	for _, bad := range []string{"", "vault:v1", "nope:v1:AAAA", "vault:v1:AAAA"} {
		if _, err := jwsSignature(bad); err == nil {
			t.Errorf("accepted %q", bad)
		}
	}
}
