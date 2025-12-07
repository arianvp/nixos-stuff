{ pkgs, ... }:

let
  pause = pkgs.dockerTools.pullImage (import ./images/pause.nix);
in
{
  # TODO: Upstream sets watchdog. NixOS doesn't.
  # Again the problem is that NixOS sucks
  virtualisation.containers.enable = true;
  virtualisation.cri-o.enable = true;
  virtualisation.podman.enable = true;

  systemd.services.podman-load-pause = {
    wantedBy = [ "crio.service" ];
    before = [ "crio.service" ];
    serviceConfig = {
      Type = "oneshot";
      StandardInput = "file:${pause}";
      ExecStart = "${pkgs.podman}/bin/podman load";
    };
  };

}
