{ lib, config, ... }:
{
  config = lib.mkIf config.kubernetes.kubelet.enable {
    # TODO: Upstream sets watchdog. NixOS doesn't.
    virtualisation.cri-o.enable = true;

    kubernetes.kubelet.settings.containerRuntimeEndpoint = lib.mkDefault "unix:///run/crio/crio.sock";

    systemd.services.kubelet = {
      after = [ "crio.service" ];
      requires = [ "crio.service" ];
    };
  };
}
