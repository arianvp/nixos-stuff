{ config, pkgs, lib, modulesPath, ... }:
with lib;
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };
  boot = {
    growPartition = true;
    kernelParams = [ "console=ttyS0" "panic=1" "boot.panic_on_fail" ];
    initrd.kernelModules = [ "virtio_scsi" ];
    kernelModules = [ "virtio_pci" "virtio_net" ];
    loader = {
      grub.device = "/dev/vda";
      timeout = 0;
      grub.configurationLimit = 0;
    };
  };
  services.openssh = {
    enable = true;
    permitRootLogin = "prohibit-password";
    passwordAuthentication = mkDefault false;
  };
  networking = {
    firewall.allowedTCPPorts = [ 22 ];
    hostName = mkDefault ""; # use dhcp
    useNetworkd = true;
  };

  systemd.services.digitalocean-set-hostname = {
    path = [ pkgs.curl pkgs.nettools ];
    description = "Set hostname provided by Digitalocean";
    wantedBy = [ "multi-user.target" ];
    script = ''
      set -e
      DIGITALOCEAN_HOSTNAME=$(curl --retry-connrefused http://169.254.169.254/metadata/v1/hostname)
      hostname $DIGITALOCEAN_HOSTNAME
    '';
    unitConfig = {
      After =  [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.services.digitalocean-ssh-keys = {
    description = "Setting ssh key";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.curl ];
    script = ''
      set -e
      mkdir -m 0700 -p /root/.ssh
      curl --retry-connrefused --output /root/.ssh/authorized_keys http://169.254.169.254/metadata/v1/public-keys
      chmod 600 /root/.ssh/authorized_keys
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    unitConfig = {
      ConditionFileExists = "!/root/.ssh/authorized_keys";
      After =  [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
  };
}
