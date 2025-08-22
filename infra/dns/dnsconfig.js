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
  CAA("@", "issue", "letsencrypt.org"),
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
  CAA("@", "issue", "letsencrypt.org"),
  TXT("@", "v=spf1 -all"),
  TXT("_dmarc", "v=DMARC1;p=reject;"),
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
);

D(
  "authguard.dev",
  REG_TRANSIP,
  DnsProvider(DSP_TRANSIP),
  DefaultTTL(86400),
  CAA("@", "issue", "letsencrypt.org"),
  MX("@", 10, "mx01.mail.icloud.com."),
  MX("@", 10, "mx02.mail.icloud.com."),
  TXT("@", "apple-domain=2KW4nPwGshaRqKSi"),
  CNAME("sig1._domainkey", "sig1.dkim.authguard.dev.at.icloudmailadmin.com."),
  TXT("@", "v=spf1 include:icloud.com ~all"),
  DMARC_BUILDER({
    policy: "quarantine",
    percent: 100,
    ttl: 60,
  }),
);

D(
  "kubeauth.dev",
  REG_TRANSIP,
  DnsProvider(DSP_TRANSIP),
  DefaultTTL(3600),
  CAA("@", "issue", "letsencrypt.org"),
  TXT("@", "v=spf1 -all"),
  TXT("_dmarc", "v=DMARC1;p=reject;"),
);

D(
  "snorco.nl",
  REG_TRANSIP,
  DnsProvider(DSP_TRANSIP),
  DefaultTTL(60),
  CAA("@", "issue", "letsencrypt.org"),
  TXT("@", "v=spf1 -all"),
  TXT("_dmarc", "v=DMARC1;p=reject;"),
);

D(
  "passkey.exchange",
  REG_CLOUDFLARE,
  DnsProvider(DSP_CLOUDFLARE),
  DefaultTTL(1),
  CAA("@", "issue", "letsencrypt.org"),
  TXT("@", "v=spf1 -all"),
  TXT("_dmarc", "v=DMARC1;p=reject;"),
);
