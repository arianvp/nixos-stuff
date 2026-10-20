package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"math/big"
	"net"
	"net/url"
	"testing"
	"time"

	credentialcomposerv1 "github.com/spiffe/spire-plugin-sdk/proto/spire/plugin/server/credentialcomposer/v1"
	configv1 "github.com/spiffe/spire-plugin-sdk/proto/spire/service/common/config/v1"
)

const testConfig = `{
  "subjects": [
    {"spiffe_id": "spiffe://example.org/k8s/node/([^/]+)", "common_name": "system:node:$1", "organizations": ["system:nodes"]},
    {"spiffe_id": "spiffe://example.org/k8s/system/([^/]+)", "common_name": "system:$1"},
    {"spiffe_id": "(spiffe://.+)", "common_name": "$1"}
  ],
  "ip_addresses": {
    "spiffe://example.org/k8s/kube-apiserver/a": ["fd00::1", "192.0.2.1"]
  }
}`

func compose(t *testing.T, spiffeID string, dnsNames ...string) *credentialcomposerv1.X509SVIDAttributes {
	t.Helper()
	p := new(plugin)
	if _, err := p.Configure(context.Background(), &configv1.ConfigureRequest{HclConfiguration: testConfig}); err != nil {
		t.Fatal(err)
	}
	resp, err := p.ComposeWorkloadX509SVID(context.Background(), &credentialcomposerv1.ComposeWorkloadX509SVIDRequest{
		SpiffeId: spiffeID,
		Attributes: &credentialcomposerv1.X509SVIDAttributes{
			Subject: &credentialcomposerv1.DistinguishedName{Country: []string{"US"}, Organization: []string{"SPIRE"}},
			DnsSans: dnsNames,
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	return resp.Attributes
}

func TestSubjects(t *testing.T) {
	for _, tc := range []struct {
		id, cn string
		orgs   []string
	}{
		{"spiffe://example.org/k8s/node/worker1", "system:node:worker1", []string{"system:nodes"}},
		{"spiffe://example.org/k8s/system/kube-proxy", "system:kube-proxy", nil},
		{"spiffe://example.org/k8s/node/a/b", "spiffe://example.org/k8s/node/a/b", nil},
		{"spiffe://example.org/other", "spiffe://example.org/other", nil},
	} {
		attrs := compose(t, tc.id)
		if attrs.Subject.CommonName != tc.cn {
			t.Errorf("%s: CN = %q, want %q", tc.id, attrs.Subject.CommonName, tc.cn)
		}
		if len(attrs.Subject.Organization) != len(tc.orgs) || (len(tc.orgs) > 0 && attrs.Subject.Organization[0] != tc.orgs[0]) {
			t.Errorf("%s: O = %q, want %q", tc.id, attrs.Subject.Organization, tc.orgs)
		}
		if len(attrs.ExtraExtensions) != 0 {
			t.Errorf("%s: unexpected extensions %v", tc.id, attrs.ExtraExtensions)
		}
	}
}

// The SAN extension must survive crypto/x509, which is what SPIRE signs with.
func TestIPAddresses(t *testing.T) {
	id := "spiffe://example.org/k8s/kube-apiserver/a"
	attrs := compose(t, id, "kubernetes.default.svc")
	if len(attrs.ExtraExtensions) != 1 {
		t.Fatalf("extensions = %v", attrs.ExtraExtensions)
	}
	ext := attrs.ExtraExtensions[0]

	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	uri, _ := url.Parse(id)
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: attrs.Subject.CommonName},
		NotBefore:    time.Now(),
		NotAfter:     time.Now().Add(time.Hour),
		URIs:         []*url.URL{uri},
		DNSNames:     attrs.DnsSans,
		ExtraExtensions: []pkix.Extension{{
			Id:    asn1.ObjectIdentifier{2, 5, 29, 17},
			Value: ext.Value,
		}},
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	if len(cert.URIs) != 1 || cert.URIs[0].String() != id {
		t.Errorf("URIs = %v", cert.URIs)
	}
	if len(cert.DNSNames) != 1 || cert.DNSNames[0] != "kubernetes.default.svc" {
		t.Errorf("DNSNames = %v", cert.DNSNames)
	}
	want := []net.IP{net.ParseIP("fd00::1"), net.ParseIP("192.0.2.1")}
	if len(cert.IPAddresses) != len(want) || !cert.IPAddresses[0].Equal(want[0]) || !cert.IPAddresses[1].Equal(want[1]) {
		t.Errorf("IPAddresses = %v, want %v", cert.IPAddresses, want)
	}
	if err := cert.VerifyHostname("fd00::1"); err != nil {
		t.Error(err)
	}
}
