{ lib, config, ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;
    openMulticastPort = true;
    settings = {
      IfName = "ygg0";
      Peers =
        [
          "tcp://ygg1.mk16.de:1337?key=0000000087ee9949eeab56bd430ee8f324cad55abf3993ed9b9be63ce693e18a"
          "quic://vpn.itrus.su:7993"
          "ws://vpn.itrus.su:7994"
          "tcp://5.2.76.123:43212"
          # openwrt
          "quic://ip4.home.flokli.io:6443"
          "tls://ip4.home.flokli.io:6443"
          "quic://ip6.home.flokli.io:6443"
          "tls://ip6.home.flokli.io:6443"
          "quic://nx01.flokli.de:6443"
          "tls://nx01.flokli.de:6443"
          "wss://nx01.flokli.de:443/ygg"
        ];
      MulticastInterfaces = [
        # ethernet is preferred over wifi
        {
          Regex = "(eth,|en).*";
          Beacon = true;
          Listen = true;
          Port = 5400;
          Priority = 1024;
        }
        {
          Regex = "(wl).*";
          Beacon = true;
          Listen = true;
          Port = 5400;
          Priority = 1025;
        }
      ];
    };
  };
  networking.firewall.allowedTCPPorts =
    [ 5400 ];
}
