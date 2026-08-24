{ noctalia }:
{ ... }:
{
  home-manager.sharedModules = [
    noctalia.homeModules.default
    ../home/noctalia.nix
  ];
}
