// Command spire-credentialcomposer-x509 is a SPIRE server CredentialComposer
// plugin that sets the subject and IP SANs of workload X509-SVIDs based on
// their SPIFFE ID.
//
// SPIRE derives the subject of an X509-SVID from its first DNS name and cannot
// issue IP SANs. Software that authenticates X.509 clients by subject (e.g.
// Kubernetes, which reads the user from the CN and groups from O), or whose
// clients connect by IP address, needs both.
//
// The plugin is configured with a JSON file, passed with plugin_data_file:
//
//	{
//	  "subjects": [
//	    {
//	      "spiffe_id": "spiffe://example.org/k8s/node/([^/]+)",
//	      "common_name": "system:node:$1",
//	      "organizations": ["system:nodes"]
//	    }
//	  ],
//	  "ip_addresses": {
//	    "spiffe://example.org/k8s/kube-apiserver/node1": ["2001:db8::1"]
//	  }
//	}
//
// The first subject rule whose spiffe_id regular expression matches the whole
// SPIFFE ID sets the common name and organizations; $1 etc. expand to its
// submatches. ip_addresses lists IP SANs per SPIFFE ID.
package main

import (
	"context"
	"encoding/asn1"
	"encoding/json"
	"fmt"
	"net"
	"regexp"
	"sync"

	"github.com/spiffe/spire-plugin-sdk/pluginmain"
	credentialcomposerv1 "github.com/spiffe/spire-plugin-sdk/proto/spire/plugin/server/credentialcomposer/v1"
	configv1 "github.com/spiffe/spire-plugin-sdk/proto/spire/service/common/config/v1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

const oidSubjectAltName = "2.5.29.17"

type subjectRule struct {
	SPIFFEID      string   `json:"spiffe_id"`
	CommonName    string   `json:"common_name"`
	Organizations []string `json:"organizations"`

	re *regexp.Regexp
}

type config struct {
	Subjects    []*subjectRule      `json:"subjects"`
	IPAddresses map[string][]string `json:"ip_addresses"`

	ips map[string][]net.IP
}

func parseConfig(data string) (*config, error) {
	cfg := new(config)
	if err := json.Unmarshal([]byte(data), cfg); err != nil {
		return nil, fmt.Errorf("plugin data must be JSON (use plugin_data_file): %w", err)
	}
	for _, rule := range cfg.Subjects {
		re, err := regexp.Compile("^(?:" + rule.SPIFFEID + ")$")
		if err != nil {
			return nil, fmt.Errorf("invalid spiffe_id pattern %q: %w", rule.SPIFFEID, err)
		}
		rule.re = re
	}
	cfg.ips = make(map[string][]net.IP, len(cfg.IPAddresses))
	for id, addrs := range cfg.IPAddresses {
		for _, addr := range addrs {
			ip := net.ParseIP(addr)
			if ip == nil {
				return nil, fmt.Errorf("invalid IP address %q for %s", addr, id)
			}
			cfg.ips[id] = append(cfg.ips[id], ip)
		}
	}
	return cfg, nil
}

type plugin struct {
	credentialcomposerv1.UnimplementedCredentialComposerServer
	configv1.UnimplementedConfigServer

	mu  sync.RWMutex
	cfg *config
}

func (p *plugin) Configure(_ context.Context, req *configv1.ConfigureRequest) (*configv1.ConfigureResponse, error) {
	cfg, err := parseConfig(req.HclConfiguration)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, err.Error())
	}
	p.mu.Lock()
	p.cfg = cfg
	p.mu.Unlock()
	return &configv1.ConfigureResponse{}, nil
}

func (p *plugin) ComposeWorkloadX509SVID(_ context.Context, req *credentialcomposerv1.ComposeWorkloadX509SVIDRequest) (*credentialcomposerv1.ComposeWorkloadX509SVIDResponse, error) {
	p.mu.RLock()
	cfg := p.cfg
	p.mu.RUnlock()
	if cfg == nil {
		return nil, status.Error(codes.FailedPrecondition, "not configured")
	}
	attrs := req.Attributes
	if attrs == nil {
		return nil, status.Error(codes.InvalidArgument, "request missing attributes")
	}

	for _, rule := range cfg.Subjects {
		match := rule.re.FindStringSubmatchIndex(req.SpiffeId)
		if match == nil {
			continue
		}
		if attrs.Subject == nil {
			attrs.Subject = &credentialcomposerv1.DistinguishedName{}
		}
		expand := func(template string) string {
			return string(rule.re.ExpandString(nil, template, req.SpiffeId, match))
		}
		attrs.Subject.CommonName = expand(rule.CommonName)
		attrs.Subject.Organization = nil
		for _, org := range rule.Organizations {
			attrs.Subject.Organization = append(attrs.Subject.Organization, expand(org))
		}
		break
	}

	if ips := cfg.ips[req.SpiffeId]; len(ips) > 0 {
		ext, err := subjectAltName(req.SpiffeId, attrs.DnsSans, ips)
		if err != nil {
			return nil, status.Error(codes.Internal, err.Error())
		}
		extensions := []*credentialcomposerv1.X509Extension{ext}
		for _, e := range attrs.ExtraExtensions {
			if e.Oid != oidSubjectAltName {
				extensions = append(extensions, e)
			}
		}
		attrs.ExtraExtensions = extensions
	}

	return &credentialcomposerv1.ComposeWorkloadX509SVIDResponse{Attributes: attrs}, nil
}

// subjectAltName builds the complete SAN extension. When the certificate
// template carries one in its extra extensions, crypto/x509 uses it instead of
// generating one from the template's URIs and DNS names, so it has to repeat
// those.
func subjectAltName(spiffeID string, dnsNames []string, ips []net.IP) (*credentialcomposerv1.X509Extension, error) {
	// GeneralName tags, RFC 5280 section 4.2.1.6
	const (
		tagDNSName = 2
		tagURI     = 6
		tagIP      = 7
	)
	names := []asn1.RawValue{{Tag: tagURI, Class: asn1.ClassContextSpecific, Bytes: []byte(spiffeID)}}
	for _, name := range dnsNames {
		names = append(names, asn1.RawValue{Tag: tagDNSName, Class: asn1.ClassContextSpecific, Bytes: []byte(name)})
	}
	for _, ip := range ips {
		if ip4 := ip.To4(); ip4 != nil {
			ip = ip4
		}
		names = append(names, asn1.RawValue{Tag: tagIP, Class: asn1.ClassContextSpecific, Bytes: ip})
	}
	value, err := asn1.Marshal(names)
	if err != nil {
		return nil, fmt.Errorf("marshaling subject alternative names: %w", err)
	}
	return &credentialcomposerv1.X509Extension{Oid: oidSubjectAltName, Value: value}, nil
}

func main() {
	p := new(plugin)
	pluginmain.Serve(
		credentialcomposerv1.CredentialComposerPluginServer(p),
		configv1.ConfigServiceServer(p),
	)
}
