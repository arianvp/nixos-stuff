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

  systemd.services.opentelemetry-collector.serviceConfig.LoadCredential = "honeycomb-ingest-key";
  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    settings = {
      extensions.bearertokenauth = {
        filename = "\${env:CREDENTIALS_DIRECTORY}/honeycomb-ingest-key";
        header = "x-honeycomb-team";
        scheme = "";
      };
      exporters.otlp = {
        endpoint = "api.eu1.honeycomb.io:443";
        auth.authenticator = "bearertokenauth";
      };
      receivers.journald = {
        # TODO: Cursor
        directory = "/var/log/journal";
      };
      receivers.hostmetrics = {

      };
      processors."resourcedetection" = {
        detectors = [
          "system"
          "env" # OTEL_RESOURCE_ATTRIBUTES
        ];
        system.hostname_sources = [ "os" ];
      };
      processors.batch = { };
      service = {
        extensions = [ "bearertokenauth" ];
        pipelines = {
          metrics = {
            receivers = [ "hostmetrics" ];
            processors = [ "resourcedetection" ];
            exporters = [ "otlp" ];
          };
          logs = {
            receivers = [ "journald" ];
            processors = [
              "resourcedetection"
              "batch"
            ];
            exporters = [ "otlp" ];
          };
        };
      };
    };
  };
}
