# A sealed appliance: no shell, no logins, nothing that survives a reboot.
# There is nothing to log in to, so no operator can reach what it runs.
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/image-based-appliance.nix"
    "${modulesPath}/profiles/bashless.nix"
  ];

  boot.loader.grub.enable = false;

  users.allowNoPasswordLogin = true;

  fileSystems."/" = {
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };
}
