{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./network.nix
    ./spire.nix
    ./prometheus.nix
    ./he-ddns.nix

    # TODO: something better
    ../../modules/base-interactive.nix
    ../../modules/hostname.nix

    ../../modules/ssh.nix
    ../../modules/sshd.nix
    ../../modules/monitoring.nix
    ../../modules/yggdrasil.nix
    ../../modules/tailscale.nix
    ../../modules/prometheus.nix
    ../../modules/alertmanager.nix
    ../../modules/opentelemetry-collector
    ../../modules/opentelemetry-collector/resource-attributes.nix
    ../../modules/opentelemetry-collector/journald-receiver.nix
    ../../modules/opentelemetry-collector/journald-receiver-prometheus.nix
    ../../modules/opentelemetry-collector/journald-receiver-etcd.nix
    # ../../modules/opentelemetry-collector/journald-receiver-raw.nix
    ../../modules/opentelemetry-collector/exporter-honeycomb.nix
    # ../../modules/opentelemetry-collector/exporter-dash0.nix
    # ../../modules/opentelemetry-collector/exporter-grafanacloud.nix

    ../../modules/kubernetes/kubernetes.nix

    ../../websites/nixos.sh
  ];

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

  system.switch.inhibitors.kernel = "${config.boot.kernelPackages.kernel}";

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

  users.users.picnoir = {
    isNormalUser = true;
    extraGroups = [ "nix-trusted-users" ];
  };

  services.openssh.settings.Banner = "${pkgs.writeText "ssh-banner" ''

    ================================================================================
                            AUTHORIZED ACCESS ONLY
    ================================================================================

    NOTICE: This system is located on a private residential network in Germany
    and is subject to monitoring and logging in accordance with applicable
    German and European Union law, including but not limited to the
    Telekommunikation-Digitale-Dienste-Datenschutz-Gesetz (TDDDG) and the
    General Data Protection Regulation (GDPR/DSGVO).

    By connecting to this system, you acknowledge and agree to the following:

      1. You will NOT use this system or network to engage in any unlawful
         activity, including but not limited to copyright infringement, unauthorized
         distribution of copyrighted material, or any other activity prohibited
         under German law (including the Urheberrechtsgesetz, UrhG).

      2. All network activity may be logged and monitored. These logs may be
         provided to law enforcement or judicial authorities upon lawful request.

      3. You assume FULL LEGAL LIABILITY for any and all activity conducted
         through this connection. The network operator shall not be held
         responsible for any violations of law committed by connected users.

      4. Unauthorized access or misuse of this system may result in civil and
         criminal prosecution under applicable German and EU law.

    If you do not agree to these terms, disconnect immediately.

    ================================================================================

  ''}";

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
}
