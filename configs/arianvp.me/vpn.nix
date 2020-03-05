{ config, pkgs, lib, ... }: {
  options.arianvp.vpn = {
    privateKeyFile = lib.mkOption {
      type = lib.types.file;
      description = "The private key. must be root:systemd-networkd 0640";
    };

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.string;
    };

  };

  config,systemd.network = {
    netdevs.wireguard-server = {
      netdevConfig = {
      };
      wireguardConfig = {
      };
      wireguardPeers =
      let mkWireguardPeer = i: publicKey: {
      };
      in lib.imap0 mkWireguardPeer cfg.peers;
    };
  };
}
