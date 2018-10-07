{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/vda"; # or "nodev" for efi only

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keyFiles = [ (pkgs.fetchurl { url = "https://github.com/arianvp.keys"; sha256 = "0v6hsr6xcpw7b5cdlb312jm4jy1dahqll8v8ppgcbrfgpxp5gmm6";}) ];

  services.openssh.passwordAuthentication = false;
  

  system.stateVersion = "18.03"; # Did you read the comment?

}
