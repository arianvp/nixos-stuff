let
  token = "wi1tll.gham5k7iy47gs8od";
  zone = "cluster";
in
/*
  Network = {
    "70-container-host0" = {
      Match = { Virtualization = "container"; Name = "host0"; };
      IPV6AcceptRA = "yes";
    };
    "70-container-vz" = {
      Match = { Driver = "bridge"; Name = "vz-*"; };
      # I don't need an address I think because I'm not masquerading?
      IPForward = "ipv6";
      IPv6PrefixDelegation = "static";
      IPv6Prefix = [
        { Prefix = "fc00::feef::feef::/64" };  # needs to be a public prefix
      ];
    };
  };
*/
{
  master1 =
    { ... }:
    {
      systemd.network.networks."80-container-host0" = {
        networkConfig.Address = "fc00::feef::feef::1/64";
      };
      kubeadm.control-plane-init = {
        enable = true;
        inherit token;
      };
    };
  worker1 =
    { ... }:
    {
      kubeadm.worker-join = {
        enable = true;
        inherit token;
      };
    };
}
