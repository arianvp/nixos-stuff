{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # ../../modules/monitoring.nix
    ../../modules/vmspawn.nix
    ./soft-reboot.nix
    ../../modules/spire/agent.nix
    ../../modules/spire/server.nix
    ./ci.nix
  ];

  security.auditd.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Virtualization.framework EFI driver doesnt' seem to support graphics anyway
  boot.consoleLogLevel = 3;
  boot.loader.timeout = 20;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.initrd.compressor = "cat";
  boot.initrd.systemd.enable = true;
  # system.etc.overlay.enable = true;
  virtualisation.rosetta.enable = true;
  # virtualisation.podman.enable = true;
  services.getty.autologinUser = "arian";
  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # Set your time zone.
  # See https://github.com/NixOS/nixpkgs/issues/311125
  # time.timeZone = "Europe/Amsterdam";
  networking.firewall.enable = false;
  # programs.nix-ld.enable = true;
  systemd.targets.network-online.wantedBy = lib.mkForce [ ];
  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = [
      pkgs.vim
      pkgs.git
      pkgs.direnv
      # pkgs.bpftrace
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMaGVuvE+aNyuAu0E9m5scVhmnVgAutNqridbMnc261cHQwecih720LCqDwTgrI3zbMwixBuU422AK0N81DyekQ= arian@Arians-MacBook-Pro.local"
    ];
  };

  services.openssh.enable = true;
  services.openssh.startWhenNeeded = true;

  # Systemd conveniently ships with this service that will check if no services failed
  # https://www.freedesktop.org/software/systemd/man/systemd-boot-check-no-failures.service.html
  # This is part of https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/
  systemd.additionalUpstreamSystemUnits = [ "systemd-boot-check-no-failures.service" ];

  systemd.oomd.enableSystemSlice = true;

  swapDevices = [
    {
      device = "/var/lib/swap";
      size = 4 * 1024;
    }
  ];

  # TODO Fix upstream
  # systemd.targets.boot-complete.requires = [ "systemd-boot-check-no-failures.service" ];

  boot.swraid.enable = true;
  programs.bcc.enable = true;

  environment.systemPackages = [ pkgs.direnv ];
  programs.zsh.enable = true;
  programs.bash.interactiveShellInit = ''
    eval "$(direnv hook bash)"
  '';
  nix.settings.trusted-users = [ "@wheel" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "fetch-closure"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?A

  spire.agent = {
    enable = true;
    trustDomain = "frickel.consulting";
    trustBundleFormat = "spiffe";
    joinToken = "61cdef30-7ee0-4b51-81aa-c8cb2007df3b";
  };

  systemd.services.teleport.serviceConfig.StateDirectory = "teleport";
  /*
    version: v3
    teleport:
      nodename: utm
      data_dir: /var/lib/teleport
      log:
        output: stderr
        severity: INFO
        format:
          output: text
      ca_pin: ""
      diag_addr: ""
    auth_service:
      enabled: "yes"
      listen_addr: 0.0.0.0:3025
      cluster_name: utm-1.bunny-minnow.ts.net
      proxy_listener_mode: multiplex
    ssh_service:
      enabled: "yes"
    proxy_service:
      enabled: "yes"
      web_listen_addr: 0.0.0.0:443
      public_addr: utm-1.bunny-minnow.ts.net:443
      https_keypairs: []
      https_keypairs_reload_interval: 0s
      acme:
        enabled: "yes"
  */
  services.teleport = {
    enable = true;
    settings = {
      version = "v3";
      teleport.data_dir = "/var/lib/teleport";
      auth_service = {
        enabled = true;
        cluster_name = "utm-1.bunny-minnow.ts.net";
        proxy_listener_mode = "multiplex";
      };
      proxy_service = {
        enabled = true;
        public_addr = "utm-1.bunny-minnow.ts.net:443";
      };

      ssh_service.enabled = true;
    };
  };
  services.tailscale.enable = true;

}
