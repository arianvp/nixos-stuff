{
  systemd.network = {
    # netdevs."00-lol" = {
    #   netdevConfig = {
    #     Kind = "veth";
    #     Name = "veth-lol";
    #   };
    #   peerConfig = {
    #     Name = "veth-loool";
    #   };
    # };
    # networks."00-veth" = {
    #   matchConfig = { Name = "ve-*"; Driver = "veth"; };
    #   networkConfig = {
    #     # I hope this is enough to propagate RAs from my router to the
    #     # container
    #     IPForward = "ipv6";
    #     # IPv6AcceptRA = "yes";
    #     IPv6ProxyNDP = "yes";
    #   };
    # };
  };
  services.systemd-nspawn.machines = {
    "test1".config = { ... }: {
      networking.firewall.allowedTCPPorts = [ 80 ];
      services.nginx.enable = true;
      systemd.network.networks."00-host0" = {
          matchConfig = { Name = "host0"; Virtualization = "container"; };
          networkConfig = {
            IPv6AcceptRA = "yes";
            # This is the default
            # IPv6AcceptRA = "yes";
          };
      };
    };
  };
}
