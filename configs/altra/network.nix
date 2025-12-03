{ lib, config, ... }:
{
  options = {
    networking.wg.enable = lib.mkEnableOption "wireguard tunnel to France";
  };
  config = lib.mkMerge [
    {
      networking.useDHCP = false;
      networking.useNetworkd = lib.mkDefault true;
    }
    {

      systemd.network = {

        networks.bmc = {
          matchConfig.Name = "usb0";
          networkConfig = {
            LinkLocalAddressing = "yes";
            MulticastDNS = "yes";
          };
        };

        netdevs."10-bond0" = {
          netdevConfig = {
            Name = "bond0";
            Kind = "bond";
          };
          # TODO: My switch doesn't support LACP
          bondConfig = {
            Mode = "active-backup";
            MIIMonitorSec = "100ms";
          };
        };

        networks."20-bond0-slaves" = {
          matchConfig = {
            Driver = "ixgbe";
            Property = [
              "ID_MODEL_ID=0x1563"
              "ID_VENDOR_ID=0x8086"
            ];
          };
          networkConfig.Bond = "bond0";
        };

        networks."30-bond0" = {
          matchConfig.Name = "bond0";
          networkConfig = {
            DHCP = "yes";
            MulticastDNS = "yes";
          };
        };

      };
    }
    (lib.mkIf config.networking.wg.enable {
      systemd.network.networks.wg0 = {
        matchConfig = {
          Name = "wg0";
        };
        address = [ "2a00:5880:1404:103::/64" ];
        routes = [
          {
            Gateway = "2a00:5880:1404:101:cafe:cafe:cafe:cafe";
            GatewayOnLink = "yes";
          }
        ];
      };

      systemd.network.netdevs."80-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
          MTUBytes = "1416";
        };
        wireguardConfig = {
          PrivateKeyFile = "/etc/credstore/wireguard.key";
        };
        wireguardPeers = [
          {
            PublicKey = "0gBdqxLAMvm9sgGP5ujGRFE6rHDko8vl5UnBm2q58y4=";
            Endpoint = "hardin.alternativebit.fr:51818";
            PersistentKeepalive = 15;
            AllowedIPs = "0.0.0.0/0,::/0";
          }
        ];
      };
    })
  ];
}
