package main

import (
	"bytes"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
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
