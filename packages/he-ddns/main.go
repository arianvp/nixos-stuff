// he-ddns watches a network interface for IPv6 global address changes via
// rtnetlink and notifies dyn.dns.he.net so its AAAA record tracks the
// configured stable global address.
package main

import (
	"flag"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"

	"github.com/vishvananda/netlink"
	"github.com/vishvananda/netlink/nl"
	"golang.org/x/sys/unix"
)

const updateURL = "https://dyn.dns.he.net/nic/update"

func main() {
	var (
		ifaceName = flag.String("interface", "", "interface to watch (required)")
		hostname  = flag.String("hostname", "", "HE.net DDNS hostname (required)")
	)
	flag.Parse()
	if *ifaceName == "" || *hostname == "" {
		flag.Usage()
		os.Exit(4)
	}

	link, err := netlink.LinkByName(*ifaceName)
	if err != nil {
		log.Fatalf("interface %q: %v", *ifaceName, err)
	}
	ifindex := link.Attrs().Index

	credDir := os.Getenv("CREDENTIALS_DIRECTORY")
	if credDir == "" {
		log.Fatal("CREDENTIALS_DIRECTORY is not set; expected systemd LoadCredential")
	}
	keyBytes, err := os.ReadFile(filepath.Join(credDir, "he-ddns.key"))
	if err != nil {
		log.Fatalf("read credential: %v", err)
	}
	key := strings.TrimSpace(string(keyBytes))

	updates := make(chan netlink.AddrUpdate)
	if err := netlink.AddrSubscribe(updates, nil); err != nil {
		log.Fatalf("netlink subscribe: %v", err)
	}

	existing, err := netlink.AddrList(link, nl.FAMILY_V6)
	if err != nil {
		log.Fatalf("netlink addrlist: %v", err)
	}
	for _, a := range existing {
		if !eligible(a.IP, a.Scope, a.Flags) {
			continue
		}
		if err := updateHE(*hostname, key, a.IP); err != nil {
			log.Printf("update failed for %s: %v", a.IP, err)
		}
	}

	for upd := range updates {
		if !upd.NewAddr || upd.LinkIndex != ifindex || upd.LinkAddress.IP.To4() != nil {
			continue
		}
		if !eligible(upd.LinkAddress.IP, upd.Scope, upd.Flags) {
			continue
		}
		if err := updateHE(*hostname, key, upd.LinkAddress.IP); err != nil {
			log.Printf("update failed for %s: %v", upd.LinkAddress.IP, err)
		}
	}
	log.Fatal("netlink subscription closed")
}

func eligible(ip net.IP, scope, flags int) bool {
	if scope != int(unix.RT_SCOPE_UNIVERSE) || flags&unix.IFA_F_TEMPORARY != 0 {
		return false
	}
	return !ip.IsPrivate()
}

func updateHE(hostname, key string, ip net.IP) error {
	req, err := http.NewRequest("POST", updateURL, strings.NewReader(url.Values{"myip": {ip.String()}}.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.SetBasicAuth(hostname, key)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	log.Print(strings.TrimSpace(string(body)))
	return nil
}
