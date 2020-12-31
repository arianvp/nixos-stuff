let
  config = {
    services.nginx.enable = true;
    networking.firewall.enable = false;
    systemd.network.networks."00-host0" = {
      matchConfig.Name = "host0";
      networkConfig = { };
    };
  };
in
{
  services.systemd-nspawn.machines = {
    test1 = { inherit config; };
    test2 = { inherit config; };
    test3 = { inherit config; };
    test4 = { inherit config; };
    test5 = { inherit config; };
  };

  networking.firewall.enable = false;
  networking.firewall.trustedInterfaces = [ "ve-test1" ];
  systemd.network.netdevs = {
    "00-vz-nixos" = {
      netdevConfig = {
        Name = "vb-nixos";
        Kind = "bridge";
      };
    };
  };
  systemd.network.networks = {
    "00-vb" = {
      matchConfig.Name = "vb-nixos";
      networkConfig = {
        IPv6AcceptRA = "yes";
        DHCP = "ipv4";
        IPForward = "yes";
      };
    };
    "00-ve" = {
      matchConfig.Name = "ve-*";
      networkConfig.Bridge = "vb-nixos";
    };
    "00-main" = {
      matchConfig.Name = "enp35s0";
      networkConfig.DHCP = "yes";
    };
  };
}
