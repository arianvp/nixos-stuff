{ pkgs, lib, config, ...}:
let
  cfg = config.services.kubeadm;
  commonOptions = {
    token = lib.mkOption {
      type = lib.types.string;
      description = ''
        Shared token. Generate with :
          nix run nixpkgs.kubernetes -c kubeadm token generate
      '';
    };
  };
  commonControlPlaneOptions = {
    certificateKey = lib.mkOption {
      type = lib.types.string;
      description = ''
        Used to decrypt the certificates that are uploaded to the initial control-plane node 
        Generate with:
          kubeadm alpha certs certificate-key
      '';
    };
  };
in {
  imports = [ ./kubeadm-base.nix ];
  options.services.kubeadm = {
    control-plane-init = {
      enable = lib.mkEnableOption "control-plane-init";
      tokenTTL = lib.mkOption {
        type = lib.types.string;
        default = "24h0m0s";
        example = "23h1m15s";
        description = ''
          The duration before the token is automatically deleted.  If set to "0",
          the token will never expire.

          To minimise risk, we advise setting a TTL as this token will show up in
          your Nix Store.

          If you want to add worker nodes later on TODp ajO
        '';
      };
    } // commonOptions // commonControlPlaneOptions;
    control-plane-join = {
      enable = lib.mkEnableOption "control-plane-join";
    } // commonOptions // commonControlPlaneOptions;
    worker-join = {
      enable = lib.mkEnableOption "worker-join";
    } // commonOptions;
  };

  };
  config = 
    lib.mkMerge [
      { services.kubeadm.kubelet.enable = true; };
      (lib.mkIf (cfg.control-plane-init.enable != null) {
      })
      (lib.mkIf (cfg.control-plane-join.enable != null) {
      })
      (lib.mkIf (cfg.worker-join.enable != null) {
      })
    ];
}
