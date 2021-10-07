{ ... }:
{
  # The kernel shouldn't be setting up interfaces magically for us
  boot.extraModprobeConfig = "options bonding max_bonds=0";
  networking.useDHCP = false;
  networking.useNetworkd = false;
  systemd.network = {
    enable = true;
    networks = {
      "99-main" = {
        matchConfig.Name = "en*";
        networkConfig.DHCP = "yes";
        networkConfig.LinkLocalAddressing = "yes";
      };
    };
  };
}

