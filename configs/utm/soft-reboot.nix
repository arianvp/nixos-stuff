{
  systemd.additionalUpstreamSystemUnits =
    [ "systemd-soft-reboot.service" "soft-reboot.target" ];

  systemd.services.activate-next = {
    unitConfig = { DefaultDependencies = false; };
    serviceConfig = { Type = "oneshot"; };
    wantedBy = [ "systemd-soft-reboot.service" ];
    before = [ "systemd-soft-reboot.service" ];
    script = ''
      sleep 300
    '';

  };
}
