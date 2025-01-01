{
  systemd.network.networks.main = {
    name = "en*";
    IPForward = "ipv6";
    IPv6AcceptRA = "yes";
    RequiredFamilyForOnline = "ipv6";
  };

  virtualisation.containerd.enable = true;
}
