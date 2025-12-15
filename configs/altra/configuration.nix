{
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./network.nix
    ./spire.nix
    ./prometheus.nix

    # TODO: something better
    ../../modules/base-interactive.nix
    ../../modules/hostname.nix

    ../../modules/ssh.nix
    ../../modules/monitoring.nix
    ../../modules/yggdrasil.nix
    ../../modules/tailscale.nix
    ../../modules/prometheus.nix
    ../../modules/alertmanager.nix

    ../../modules/kubernetes/kubernetes.nix

    ../../websites/nixos.sh
  ];

  # TODO: Move into something more generic?
  services.openssh.enable = true;

  services.yggdrasil.persistentKeys = true;
  security.tpm2.enable = true;

  # NOTE: temporary measure until we remove the need for sudo
  # We just mint root user certs instead
  security.sudo.wheelNeedsPassword = false;

  networking.dynamicHostName.enable = true;
  system.name = "altra";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.timeout = 20;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  # TODO: Move into something more generic?
  services.getty.autologinUser = "arian";

  # TODO: Move into something more generic?
  time.timeZone = "Europe/Amsterdam";

  # TODO: Move to base?
  networking.firewall.enable = true;

  # TODO: Move to specific modules?
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx.enable = true;

  users.users.m = {
    extraGroups = [ "nix-trusted-users" ];
    isNormalUser = true;
  };

  users.users.arian = {
    isNormalUser = true;
    extraGroups = [
      "nix-trusted-users"
      "wheel"
    ];
  };

  users.users.flokli = {
    isNormalUser = true;
    extraGroups = [ "nix-trusted-users" ];
  };

  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];

  # TODO: Do we need this?
  programs.zsh.enable = true;

  # TODO: Move to builder role?
  nix.settings.system-features = [
    "nixos-test"
    "benchmark"
    "big-parallel"
    "kvm"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?A

  systemd.services.opentelemetry-collector.serviceConfig.EnvironmentFile = "/etc/credstore/honeycomb-ingest-key";
  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    settings = {
      exporters.otlp = {
        endpoint = "api.eu1.honeycomb.io:443";
        headers = {
         "x-honeycomb-team"  = "\${env:HONEYCOMB_TOKEN}";
        };
      };
      receivers.journald = {
        # TODO: Cursor
        directory = "/var/log/journal";
        operators = [
          # Map syslog PRIORITY to OTel severity (0=emerg...7=debug)
          {
            type = "severity_parser";
            parse_from = "attributes.PRIORITY";
            preset = "none";
            mapping = {
              fatal = [ "0" "1" "2" ];    # emerg, alert, crit
              error = [ "3" ];             # err
              warn = [ "4" ];              # warning
              info = [ "5" "6" ];          # notice, info
              debug = [ "7" ];             # debug
            };
          }

          # Map systemd unit to service.name (prefer UNIT over SYSLOG_IDENTIFIER)
          { type = "copy"; from = "attributes.UNIT"; to = "resource[\"service.name\"]"; }

          # Map host information to resource attributes
          { type = "move"; from = "attributes._HOSTNAME"; to = "resource[\"host.name\"]"; }
          { type = "move"; from = "attributes._MACHINE_ID"; to = "resource[\"host.id\"]"; }

          # Map process information to OTel semantic conventions
          { type = "move"; from = "attributes._PID"; to = "attributes[\"process.pid\"]"; }
          { type = "move"; from = "attributes._EXE"; to = "attributes[\"process.executable.path\"]"; }
          { type = "move"; from = "attributes._CMDLINE"; to = "attributes[\"process.command_line\"]"; }

          # Map source code location to OTel semantic conventions
          { type = "move"; from = "attributes.CODE_FILE"; to = "attributes[\"code.filepath\"]"; }
          { type = "move"; from = "attributes.CODE_FUNC"; to = "attributes[\"code.function\"]"; }
          { type = "move"; from = "attributes.CODE_LINE"; to = "attributes[\"code.lineno\"]"; }

          # Keep systemd-specific fields in a namespace
          { type = "copy"; from = "attributes.UNIT"; to = "attributes[\"systemd.unit\"]"; }
          { type = "move"; from = "attributes.INVOCATION_ID"; to = "attributes[\"systemd.invocation_id\"]"; }
          { type = "move"; from = "attributes._SYSTEMD_CGROUP"; to = "attributes[\"systemd.cgroup\"]"; }
          { type = "move"; from = "attributes._SYSTEMD_SLICE"; to = "attributes[\"systemd.slice\"]"; }

          # Remove original/redundant journal fields
          { type = "remove"; field = "attributes.UNIT"; }
          { type = "remove"; field = "attributes.SYSLOG_IDENTIFIER"; }
          { type = "remove"; field = "attributes.PRIORITY"; }
          { type = "remove"; field = "attributes.SYSLOG_FACILITY"; }
          { type = "remove"; field = "attributes.MESSAGE_ID"; }
          { type = "remove"; field = "attributes._UID"; }
          { type = "remove"; field = "attributes._GID"; }
          { type = "remove"; field = "attributes.TID"; }
          { type = "remove"; field = "attributes._COMM"; }
          { type = "remove"; field = "attributes._CAP_EFFECTIVE"; }
          { type = "remove"; field = "attributes._BOOT_ID"; }
          { type = "remove"; field = "attributes._TRANSPORT"; }
          { type = "remove"; field = "attributes._RUNTIME_SCOPE"; }
          { type = "remove"; field = "attributes._SOURCE_REALTIME_TIMESTAMP"; }
          { type = "remove"; field = "attributes.__CURSOR"; }
          { type = "remove"; field = "attributes.__MONOTONIC_TIMESTAMP"; }
          { type = "remove"; field = "attributes.__SEQNUM"; }
          { type = "remove"; field = "attributes.__SEQNUM_ID"; }
        ];
      };
      service = {
        pipelines = {
          logs = {
            receivers = [ "journald" ];
            exporters = [ "otlp" ];
          };
        };
      };
    };
  };
}
