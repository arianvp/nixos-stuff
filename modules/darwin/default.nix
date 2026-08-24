{ home-manager }:
{ lib, ... }:
{
  imports = [
    ./common.nix
    ../overlays.nix
    ./ssh.nix
    ../nix/darwin.nix
    (lib.modules.importApply ./home-manager.nix { inherit home-manager; })
  ];
}
