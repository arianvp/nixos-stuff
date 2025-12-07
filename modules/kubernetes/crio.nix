{ ... }:

{
  # TODO: Upstream sets watchdog. NixOS doesn't.
  # Again the problem is that NixOS sucks
  virtualisation.containers.enable = true;
  virtualisation.cri-o.enable = true;
  virtualisation.podman.enable = true;

}
