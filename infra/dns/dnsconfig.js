// @ts-check
/// <reference path="types-dnscontrol.d.ts" />

// TODO: Move away from namecheap. doesn't offer API access
var REG_NAMECHEAP = NewRegistrar("none");
// NOTE: Transip doesn't offer Registrar API
var REG_TRANSIP = NewRegistrar("none");

var DSP_TRANSIP = NewDnsProvider("transip");
var DSP_DIGITALOCEAN = NewDnsProvider("digitalocean");

var DSP_CLOUDFLARE = NewDnsProvider("cloudflare");
var REG_CLOUDFLARE = NewRegistrar("none");

D(
  "arianvp.me",
  REG_NAMECHEAP,
  DnsProvider(DSP_DIGITALOCEAN),
  DefaultTTL(1800),
  //NAMESERVER("ns1.digitalocean.com."),
  //NAMESERVER("ns2.digitalocean.com."),
  //NAMESERVER("ns3.digitalocean.com."),
  A("@", "161.35.204.16"),
  MX("@", 10, "mx01.mail.icloud.com."),
  MX("@", 10, "mx02.mail.icloud.com."),
  TXT("@", "apple-domain=9qkyfBenzNmk62QX"),
  TXT("@", "v=spf1 include:icloud.com ~all"),
  CNAME(
    "sig1._domainkey",
    "sig1.dkim.arianvp.me.at.icloudmailadmin.com.",
    TTL(43200),
  ),
  DMARC_BUILDER({
    policy: "quarantine",
    percent: 100,
    ttl: 60,
  }),
  TXT("_atproto", "did=did:plc:a3g5gg7dmkkggvbtjgn7wafa"),
);

D(
  "nixos.sh",
  REG_TRANSIP,
  DnsProvider(DSP_TRANSIP),
  DefaultTTL(86400),
  TXT("@", "v=spf1 -all"),
  AAAA("altra", "202:a655:b29f:851:4fe6:cdf7:d0eb:cb0"),
  SSHFP("altra", 1, 1, "ad445dc455aba0169f429714eb34dd04e0df9dbe"),
  SSHFP(
    "altra",
    1,
    2,
    "eca257264292717185ff7d5b52eace12ec8d2f2b9b390939c1914b5c74632226",
  ),
  SSHFP("altra", 4, 1, "be25442688f8a35fbd1137caa007b9ea28984587"),
  SSHFP(
    "altra",
    4,
    2,
    "eb61040cf1a2636a25b02f0fcca654ac8913d8ac7c011560d9bad0c52548ac4e",
  ),
  TXT("_dmarc", "v=DMARC1;p=reject;"),
);

D(
  "authguard.dev",
  REG_TRANSIP,
  DnsProvider(DSP_TRANSIP),
  DefaultTTL(86400),
  A("@", "34.120.229.252"),
  MX("@", 10, "mx01.mail.icloud.com."),
  MX("@", 10, "mx02.mail.icloud.com."),
  TXT("@", "apple-domain=2KW4nPwGshaRqKSi"),
  TXT(
    "@",
    "google-site-verification=uvuZd0IFCtSQu32GfzPF6hi2sh3MD3M2AhoG-YghaGg",
  ),
  TXT("@", "v=spf1 include:icloud.com ~all"),
  TXT(
    "google-site-verification",
    "uvuZd0IFCtSQu32GfzPF6hi2sh3MD3M2AhoG-YghaGg",
  ),
  CNAME("oidc", "ghs.googlehosted.com."),
  CNAME("sig1._domainkey", "sig1.dkim.authguard.dev.at.icloudmailadmin.com."),
);

D(
  "kubeauth.dev",
  REG_TRANSIP,
  DnsProvider(DSP_TRANSIP),
  DefaultTTL(3600),
  A("@", "37.97.254.27"),
  AAAA("@", "2a01:7c8:3:1337::27"),
  MX("@", 10, "@"),
  TXT("@", "v=spf1 ~all"),
  CNAME("transip-a._domainkey", "_dkim-A.transip.email."),
  CNAME("transip-b._domainkey", "_dkim-B.transip.email."),
  CNAME("transip-c._domainkey", "_dkim-C.transip.email."),
  CNAME("www", "\@"),
  TXT("_dmarc", "v=DMARC1; p=none;"),
);

D(
  "snorco.nl",
  REG_TRANSIP,
  DnsProvider(DSP_TRANSIP),
  DefaultTTL(86400),
  A("@", "195.201.113.40"),
  AAAA("@", "2a01:4f8:1c0c:792f::1"),
  MX("@", 10, "@"),
  CNAME("ftp", "\@"),
  CNAME("mail", "\@"),
  CNAME("www", "\@"),
);

D(
  "passkey.exchange",
  REG_CLOUDFLARE,
  DnsProvider(DSP_CLOUDFLARE),
  DefaultTTL(1),
  A("@", "3.76.7.217"),
  AAAA("@", "2a05:d014:151f:ac03:d61b:fab4:cffd:b8c0"),
  CAA("@", "issue", "letsencrypt.org"),
);
