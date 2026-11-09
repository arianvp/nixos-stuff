{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.etcd;
  format = pkgs.formats.yaml { };
  defaultConfigFile = format.generate "etcd.yaml" cfg.settings;

  # etcd reads its config from a stable path, so that a deploy restarts it
  # only when restartConfig changes. Editing keys that etcd reads only on its
  # first start, such as the member list, must not restart every member.
  configPath = "etcd/etcd.yaml";
  bootstrapKeys = [
    "initial-cluster"
    "initial-cluster-state"
    "initial-cluster-token"
    "initial-advertise-peer-urls"
  ];
  restartConfig =
    if toString cfg.configFile == toString defaultConfigFile then
      format.generate "etcd-restart.yaml" (removeAttrs cfg.settings bootstrapKeys)
    else
      cfg.configFile;

  # An empty member that its peers know as started refuses to start with only
  # "has already been bootstrapped", which etcd decides the same way: the
  # peers have its client URLs. Say what to do instead.
  checkBootstrapped = pkgs.writeShellApplication {
    name = "etcd-check-bootstrapped";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.yq-go
    ];
    text = ''
      config=$1
      get() {
        yq ".[\"$1\"] // \"\"" "$config"
      }
      getTLS() {
        yq ".[\"peer-transport-security\"][\"$1\"] // \"\"" "$config"
      }

      dataDir=$(get data-dir)
      # Like etcd, go by the WAL: a failed start leaves the rest of member/ behind
      if [ -d "$dataDir/member/wal" ] || [ "$(get initial-cluster-state)" = existing ]; then
        exit 0
      fi

      name=$(get name)
      tls=()
      for opt in cacert:trusted-ca-file cert:cert-file key:key-file; do
        file=$(getTLS "''${opt#*:}")
        if [ -n "$file" ]; then
          tls+=("--''${opt%%:*}" "$file")
        fi
      done

      IFS=, read -ra peers <<< "$(get initial-cluster)"
      for peer in "''${peers[@]}"; do
        peerName=''${peer%%=*}
        url=''${peer#*=}
        if [ "$peerName" = "$name" ]; then
          continue
        fi
        # etcd's peer listener fails HTTP/2 requests from curl
        if curl --silent --fail --http1.1 --max-time 3 "''${tls[@]}" "$url/members" \
          | jq -e --arg name "$name" 'any(.[]; .name == $name and (.clientURLs | length) > 0)' > /dev/null
        then
          echo "$dataDir has no etcd data, but member $peerName knows $name as a started member of its cluster, so etcd would refuse to start with \"has already been bootstrapped\". Replace this member as described in modules/kubernetes/runbooks/etcd.md, section 4 \"Replace a member that lost its disk\"." >&2
          exit 1
        fi
      done
    '';
  };
in
{
  options.kubernetes.etcd = {
    enable = lib.mkEnableOption "etcd";

    package = lib.mkPackageOption pkgs "etcd" { };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = config.networking.hostName;
            defaultText = lib.literalExpression "config.networking.hostName";
            description = "Human-readable name for this member.";
          };
          data-dir = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/etcd";
            readOnly = true;
            description = "Path to the data directory.";
          };
          initial-cluster-state = lib.mkOption {
            type = lib.types.enum [
              "new"
              "existing"
            ];
            default = "new";
            description = ''
              `new` to found a cluster with the members of `initial-cluster`,
              `existing` to join a running cluster after
              `etcdctl member add`. etcd reads it only when the data
              directory is empty, so changing it on a running member does
              nothing. A member with an empty data directory and `new` does
              not start if its peers already know it as started; see
              `modules/kubernetes/runbooks/etcd.md`.
            '';
          };
          listen-metrics-urls = lib.mkOption {
            type = lib.types.str;
            default = "http://127.0.0.1:2381";
            description = ''
              Comma-separated URLs that serve `/metrics` and `/health`. With
              `http://` they need no client certificate, so keep them on
              loopback or a monitoring network.
            '';
          };
        };
      };
      default = { };
      description = ''
        etcd configuration file. Passing a configuration file makes etcd ignore
        all command-line flags and environment variables.
        See <https://etcd.io/docs/latest/op-guide/configuration/>.
      '';
      example = lib.literalExpression ''
        {
          listen-client-urls = "https://[::]:2379";
          advertise-client-urls = "https://etcd.example.com:2379";
          client-transport-security = {
            cert-file = "/run/etcd-svid/svid.pem";
            key-file = "/run/etcd-svid/svid.key";
            trusted-ca-file = "/etc/ssl/spire-bundle.pem";
            client-cert-auth = true;
          };
        }
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = defaultConfigFile;
      defaultText = "A file generated from kubernetes.etcd.settings";
      description = "etcd configuration file.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.etc.${configPath}.source = cfg.configFile;

    systemd.services.etcd = {
      description = "etcd key-value store";
      documentation = [ "https://etcd.io/docs/" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [ restartConfig ];
      # A member that keeps failing lands in "failed" after about a minute
      # instead of restarting forever unnoticed
      startLimitBurst = 10;
      startLimitIntervalSec = 120;
      serviceConfig = {
        Type = "notify";
        ExecStartPre = "${lib.getExe checkBootstrapped} /etc/${configPath}";
        ExecStart = "${lib.getExe' cfg.package "etcd"} --config-file /etc/${configPath}";
        StateDirectory = "etcd";
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = "5s";
        LimitNOFILE = 65536;
      };
    };
  };
}
