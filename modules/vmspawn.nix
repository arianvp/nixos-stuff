# Sets up config such that systemd-vmspawn works
{
  pkgs,
  config,
  lib,
  ...
}:
{
  environment.systemPackages = [
    pkgs.qemu_kvm
    pkgs.swtpm
    pkgs.virtiofsd
  ];
  # This allows vmspawn to find and enumarate firmwares
  environment.etc."qemu/firmware".source = "${pkgs.qemu_kvm}/share/qemu/firmware";
}
