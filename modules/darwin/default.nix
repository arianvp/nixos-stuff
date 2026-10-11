{ home-manager }:
{ lib, ... }:
{
  imports = [
    ./common.nix
    ../overlays.nix
    ./ssh.nix
    ./nix.nix
    (lib.modules.importApply ./home-manager.nix { inherit home-manager; })
  ];
}
