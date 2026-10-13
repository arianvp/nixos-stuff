// Command kube-kms-openbao is a Kubernetes KMS v2 plugin that encrypts with a
// key in OpenBao's transit secrets engine.
//
// It authenticates to OpenBao with TLS certificate auth, and reads its
// certificate, key and CA bundle from files on every TLS handshake, so that it
// keeps working when they are rotated (e.g. X509-SVIDs kept by spiffe-helper).
package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"google.golang.org/grpc"
	kmsapi "k8s.io/kms/apis/v2"
	"k8s.io/kms/pkg/service"
)

// openbao is a minimal client for the transit and cert auth APIs
type openbao struct {
	address   string
	authMount string
	role      string
	http      *http.Client

	mu     sync.Mutex
	token  string
	expiry time.Time
}

// errForbidden means the token is missing, expired or revoked
var errForbidden = errors.New("permission denied")

func newTLSConfig(certFile, keyFile, caFile string) *tls.Config {
	return &tls.Config{
		MinVersion: tls.VersionTLS12,
		GetClientCertificate: func(*tls.CertificateRequestInfo) (*tls.Certificate, error) {
			cert, err := tls.LoadX509KeyPair(certFile, keyFile)
			return &cert, err
		},
		// Verified in VerifyConnection against the current bundle instead
		InsecureSkipVerify: true,
		VerifyConnection: func(cs tls.ConnectionState) error {
			pem, err := os.ReadFile(caFile)
			if err != nil {
				return err
			}
			roots := x509.NewCertPool()
			if !roots.AppendCertsFromPEM(pem) {
				return fmt.Errorf("no certificates in %s", caFile)
			}
			if len(cs.PeerCertificates) == 0 {
				return errors.New("server presented no certificate")
			}
			intermediates := x509.NewCertPool()
			for _, cert := range cs.PeerCertificates[1:] {
				intermediates.AddCert(cert)
			}
			_, err = cs.PeerCertificates[0].Verify(x509.VerifyOptions{
				DNSName:       cs.ServerName,
				Roots:         roots,
				Intermediates: intermediates,
			})
			return err
		},
	}
}

func (o *openbao) request(ctx context.Context, method, path, token string, body, out any) error {
	var reader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(data)
	}
	req, err := http.NewRequestWithContext(ctx, method, strings.TrimSuffix(o.address, "/")+"/v1/"+path, reader)
	if err != nil {
		return err
	}
	if token != "" {
		req.Header.Set("X-Vault-Token", token)
	}
	resp, err := o.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusForbidden {
		return errForbidden
	}
	if resp.StatusCode != http.StatusOK {
		msg, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("%s %s: %s: %s", method, path, resp.Status, bytes.TrimSpace(msg))
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

func (o *openbao) login(ctx context.Context) (string, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	// Renew well before the token expires
	if o.token != "" && time.Until(o.expiry) > time.Minute {
		return o.token, nil
	}
	var resp struct {
		Auth struct {
			ClientToken   string `json:"client_token"`
			LeaseDuration int    `json:"lease_duration"`
		} `json:"auth"`
	}
	body := map[string]string{}
	if o.role != "" {
		body["name"] = o.role
	}
	if err := o.request(ctx, http.MethodPost, "auth/"+o.authMount+"/login", "", body, &resp); err != nil {
		return "", fmt.Errorf("logging in: %w", err)
	}
	o.token = resp.Auth.ClientToken
	o.expiry = time.Now().Add(time.Duration(resp.Auth.LeaseDuration) * time.Second)
	return o.token, nil
}

func (o *openbao) forget(token string) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if o.token == token {
		o.token = ""
	}
}

// call logs in as needed, and once more if the token stopped working
func (o *openbao) call(ctx context.Context, method, path string, body, out any) error {
	for attempt := 0; ; attempt++ {
		token, err := o.login(ctx)
		if err != nil {
			return err
		}
		err = o.request(ctx, method, path, token, body, out)
		if errors.Is(err, errForbidden) && attempt == 0 {
			o.forget(token)
			continue
		}
		return err
	}
}

type plugin struct {
	bao   *openbao
	mount string
	key   string
}

var _ service.Service = (*plugin)(nil)

func (p *plugin) keyID(version int) string {
	return fmt.Sprintf("%s:%d", p.key, version)
}

func (p *plugin) Encrypt(ctx context.Context, _ string, plaintext []byte) (*service.EncryptResponse, error) {
	var resp struct {
		Data struct {
			Ciphertext string `json:"ciphertext"`
			KeyVersion int    `json:"key_version"`
		} `json:"data"`
	}
	body := map[string]string{"plaintext": base64.StdEncoding.EncodeToString(plaintext)}
	if err := p.bao.call(ctx, http.MethodPost, p.mount+"/encrypt/"+p.key, body, &resp); err != nil {
		return nil, err
	}
	return &service.EncryptResponse{
		Ciphertext: []byte(resp.Data.Ciphertext),
		KeyID:      p.keyID(resp.Data.KeyVersion),
	}, nil
}

func (p *plugin) Decrypt(ctx context.Context, _ string, req *service.DecryptRequest) ([]byte, error) {
	var resp struct {
		Data struct {
			Plaintext string `json:"plaintext"`
		} `json:"data"`
	}
	body := map[string]string{"ciphertext": string(req.Ciphertext)}
	if err := p.bao.call(ctx, http.MethodPost, p.mount+"/decrypt/"+p.key, body, &resp); err != nil {
		return nil, err
	}
	return base64.StdEncoding.DecodeString(resp.Data.Plaintext)
}

// Status reports the latest version of the key, so that the API server
// starts using a new data encryption key when the transit key rotates.
func (p *plugin) Status(ctx context.Context) (*service.StatusResponse, error) {
	var resp struct {
		Data struct {
			LatestVersion int `json:"latest_version"`
		} `json:"data"`
	}
	if err := p.bao.call(ctx, http.MethodGet, p.mount+"/keys/"+p.key, nil, &resp); err != nil {
		return nil, err
	}
	return &service.StatusResponse{Version: "v2", Healthz: "ok", KeyID: p.keyID(resp.Data.LatestVersion)}, nil
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
		socket    = flag.String("socket", "/run/kube-kms-openbao/kms.sock", "Unix socket kube-apiserver connects to")
		address   = flag.String("address", "", "URL of OpenBao")
		mount     = flag.String("transit-mount", "transit", "Path of the transit secrets engine")
		key       = flag.String("key", "kubernetes", "Name of the transit key")
		authMount = flag.String("auth-mount", "cert", "Path of the cert auth method")
		role      = flag.String("role", "", "Cert auth role to log in with; any matching role if empty")
		certFile  = flag.String("cert-file", "", "Client certificate, followed by its intermediates")
		keyFile   = flag.String("key-file", "", "Client key")
		caFile    = flag.String("ca-file", "", "CA certificates to verify OpenBao with")
		timeout   = flag.Duration("timeout", 10*time.Second, "Timeout of requests from kube-apiserver")
	)
	flag.Parse()
	if *address == "" || *certFile == "" || *keyFile == "" || *caFile == "" {
		return errors.New("-address, -cert-file, -key-file and -ca-file are required")
	}

	p := &plugin{
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
	}

	_ = os.Remove(*socket)
	lis, err := net.Listen("unix", *socket)
	if err != nil {
		return err
	}
	server := grpc.NewServer(grpc.ConnectionTimeout(*timeout))
	kmsapi.RegisterKeyManagementServiceServer(server, service.NewGRPCService(*socket, *timeout, p))

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()
	go func() {
		<-ctx.Done()
		server.GracefulStop()
	}()

	slog.Info("serving", "socket", *socket, "address", *address, "key", *key)
	notifyReady()
	return server.Serve(lis)
}

func main() {
	if err := run(); err != nil {
		slog.Error("exiting", "error", err)
		os.Exit(1)
	}
}
