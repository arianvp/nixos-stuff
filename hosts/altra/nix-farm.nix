# altra as a one-node nix-grpc-store farm, federated with Numtide's
# numtide.com trust domain. Numtide people build here with their own
# X.509-SVIDs and pull the outputs back; altra holds no cache credential.
{ nix-grpc-store }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  trustDomain = config.services.spire.server.settings.server.trust_domain;
  spiffe = path: "spiffe://${trustDomain}${path}";
  socket = config.services.spire.agent.settings.agent.socket_path;
  port = 50051;
  svidDir = "/run/nix-farm-svid";
  signingDir = "/var/lib/nix-farm-signing";
  daemonUser = "nix-grpc-daemon";

  numtide = {
    farm = "grpc://farm.numtide.com:50051";
    cache = "https://cache.numtide.com";
    cacheKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
  };

  # Keeps svid.pem, svid.key, bundles.json (gRFC A87 bundle map of this and
  # every federated trust domain) and <trust-domain>.pem in $1. The daemon
  # re-reads them on its own, so a rotated SVID needs no restart.
  svidSync = pkgs.writeShellApplication {
    name = "spiffe-svid-sync";
    runtimeInputs = [
      config.services.spire.agent.package
      pkgs.coreutils
      pkgs.jq
      pkgs.openssl
      pkgs.systemd
    ];
    text = ''
      dir=$1 td=$2
      umask 027
      cd "$dir"

      # stdin: concatenated DER certificates, stdout: one base64 line each
      der_split() {
        local f b1 hl len n v
        f=$(mktemp -p .)
        cat >"$f"
        while [ -s "$f" ]; do
          b1=$(od -An -tu1 -j1 -N1 "$f" | tr -d ' ')
          if [ "$b1" -lt 128 ]; then
            hl=2 len=$b1
          else
            n=$((b1 - 128)) hl=$((2 + b1 - 128)) len=0
            for v in $(od -An -tu1 -j2 -N"$n" "$f"); do len=$((len * 256 + v)); done
          fi
          head -c $((hl + len)) "$f" | base64 -w0
          echo
          tail -c +$((hl + len + 1)) "$f" >"$f.rest"
          mv "$f.rest" "$f"
        done
        rm -f "$f"
      }
      pem() { while read -r c; do printf -- '-----BEGIN CERTIFICATE-----\n%s\n-----END CERTIFICATE-----\n' "$(echo "$c" | fold -w64)"; done; }
      bundle_of() { jq -R . | jq -s --arg td "$1" '{($td): {keys: map({kty: "EC", use: "x509-svid", x5c: [.]})}}'; }

      ready=
      while true; do
        if spire-agent api fetch x509 -socketPath "$SPIFFE_ENDPOINT_SOCKET" -output json >resp.json 2>resp.err \
          && jq -e '.svids[0]' resp.json >/dev/null; then
          svid=$(jq -r '.svids[0] | .x509_svid // .x509Svid' resp.json)
          key=$(jq -r '.svids[0] | .x509_svid_key // .x509SvidKey' resp.json)
          echo "$svid" | base64 -d | der_split | pem >svid.pem.new
          echo "$key" | base64 -d | openssl pkey -inform der -out svid.key.new
          {
            jq -r '.svids[0].bundle' resp.json | base64 -d | der_split | bundle_of "$td"
            jq -r '(.federated_bundles // .federatedBundles // {}) | to_entries[] | "\(.key) \(.value)"' resp.json \
              | while read -r name b64; do
                echo "$b64" | base64 -d >"$name.der"
                der_split <"$name.der" | pem >"$name.pem.new"
                der_split <"$name.der" | bundle_of "$name"
                rm "$name.der"
                mv "$name.pem.new" "$name.pem"
              done
          } | jq -s '{trust_domains: add}' >bundles.json.new
          jq -r '.svids[0].bundle' resp.json | base64 -d | der_split | pem >bundle.pem.new
          mv svid.key.new svid.key
          mv svid.pem.new svid.pem
          mv bundle.pem.new bundle.pem
          mv bundles.json.new bundles.json
          rm -f resp.json resp.err
          if [ -z "$ready" ]; then
            systemd-notify --ready
            ready=1
          fi
          sleep 300
          continue
        fi
        cat resp.err >&2 || true
        sleep 10
      done
    '';
  };

  # A nix with the grpc:// plugin: the system nix is Lix, which the plugin
  # does not load into. Submits to Numtide's farm as the calling user, with
  # that user's own JWT-SVID (spiffe://nixos.sh/user/<name>).
  nixWithPlugin = nix-grpc-store.lib.wrapNix pkgs pkgs.nixVersions.latest;
  numtideFarm = pkgs.writeShellApplication {
    name = "nix-numtide-farm";
    runtimeInputs = [
      config.services.spire.agent.package
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      d=''${XDG_RUNTIME_DIR:-/tmp}/nix-numtide-farm
      install -d -m 700 "$d"
      spire-agent api fetch jwt -audience ${numtide.farm} -socketPath "$SPIFFE_ENDPOINT_SOCKET" >"$d/out"
      awk '/^token\(/ { getline; gsub(/[ \t]/, ""); print; exit }' "$d/out" >"$d/token"
      system=''${NUMTIDE_FARM_SYSTEM:-x86_64-linux}
      export NIX_CONFIG="store = ${numtide.farm}?system=$system&token-file=$d/token
      eval-store = auto
      ''${NIX_CONFIG:-}"
      exec ${lib.getExe nixWithPlugin} "$@"
    '';
  };

  serviceHardening = {
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    RestrictAddressFamilies = [ "AF_UNIX" ];
  };
in
{
  imports = [ nix-grpc-store.nixosModules.server ];

  # the daemon's server certificate towards Numtide people; it is a client
  # of nothing
  services.spire.controllerManager.staticEntries.nix-farm-worker.spec = {
    parentID = spiffe "/server/altra";
    spiffeID = spiffe "/nix-farm/worker/altra";
    selectors = [ "systemd:id:nix-farm-svid.service" ];
    federatesWith = [ "numtide.com" ];
    dnsNames = [ "altra.nixos.sh" ];
  };

  services.nix-grpc-daemon = {
    enable = true;
    listen = "[::]:${toString port}";
    idleTimeout = null;
    minFree = "50G";
    tls = {
      certFile = "${svidDir}/svid.pem";
      keyFile = "${svidDir}/svid.key";
      # Mic92/nix-grpc-store#219: per-trust-domain verification, rules on
      # SPIFFE IDs. A client with no SPIFFE ID fails the handshake.
      clientSpiffeBundlesFile = "${svidDir}/bundles.json";
    };
    # `*` stays in one path segment. write = server-side builds and signed
    # imports; no unsigned imports, no worker-protocol tunnel, no build hook.
    accessRules = [
      {
        cn = "spiffe://numtide.com/user/*";
        role = "write";
      }
    ];
  };

  # nix-daemon only serves @nix-trusted-users here; the proxy user needs
  # access without becoming trusted, the daemon's roles do the gating.
  nix.settings.allowed-users = [ daemonUser ];
  nix.settings.substituters = [ numtide.cache ];
  nix.settings.trusted-public-keys = [ numtide.cacheKey ];
  # outputs leave over `nix copy`; the puller verifies this signature
  # (public key: nix key convert-secret-to-public < ${signingDir}/key)
  nix.settings.secret-key-files = [ "${signingDir}/key" ];

  systemd.services.nix-farm-signing-key = {
    description = "Nix signing key altra.nixos.sh-1";
    wantedBy = [ "multi-user.target" ];
    before = [ "nix-daemon.service" ];
    requiredBy = [ "nix-daemon.service" ];
    unitConfig.ConditionPathExists = "!${signingDir}/key";
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = baseNameOf signingDir;
      StateDirectoryMode = "0700";
      UMask = "0077";
      ExecStart = pkgs.writeShellScript "nix-farm-signing-key" ''
        ${lib.getExe config.nix.package} key generate-secret --key-name altra.nixos.sh-1 >${signingDir}/key
      '';
    };
  };

  systemd.services.nix-farm-svid = {
    description = "X.509-SVID and SPIFFE bundle map for nix-grpc-daemon";
    wantedBy = [ "multi-user.target" ];
    after = [ "spire-agent.service" ];
    wants = [ "spire-agent.service" ];
    environment.SPIFFE_ENDPOINT_SOCKET = socket;
    serviceConfig = serviceHardening // {
      Type = "notify";
      NotifyAccess = "all";
      ExecStart = "${lib.getExe svidSync} ${svidDir} ${trustDomain}";
      User = daemonUser;
      Group = daemonUser;
      RuntimeDirectory = baseNameOf svidDir;
      RuntimeDirectoryMode = "0750";
      RuntimeDirectoryPreserve = true;
      Restart = "always";
      RestartSec = 10;
    };
  };

  systemd.services.nix-grpc-daemon = {
    after = [ "nix-farm-svid.service" ];
    requires = [ "nix-farm-svid.service" ];
  };

  networking.firewall.allowedTCPPorts = [ port ];

  environment.systemPackages = [ numtideFarm ];
}
