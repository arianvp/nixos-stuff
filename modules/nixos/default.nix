{ cgroup-exporter }:
{ ... }:
{
  imports = [
    cgroup-exporter.nixosModules.default
    ./overlays.nix
    ../dnssd.nix
  ];
}
