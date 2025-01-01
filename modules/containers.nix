# A modern container runtime stuff
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    conmon
    podman
  ];
}
