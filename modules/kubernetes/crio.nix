{ ... }:

{
  # TODO: Upstream sets watchdog. NixOS doesn't.
  # Again the problem is that NixOS sucks
  virtualisation.cri-o = {
    enable = true;
  };
}
