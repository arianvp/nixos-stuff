{ ... }:
{
  nixpkgs.overlays = map import [
    ../../overlays/fonts.nix
    ../../overlays/neovim.nix
    ../../overlays/spire.nix
    ../../overlays/openssh-audit.nix
    ../../overlays/gnome-ssh-askpass4.nix
    ../../overlays/he-ddns.nix
  ];
}
