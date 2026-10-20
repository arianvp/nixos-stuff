{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.cni;
  format = pkgs.formats.json { };
in
{
  options.kubernetes.cni = {
    settings = lib.mkOption {
      type = lib.types.nullOr format.type;
      default = null;
      description = ''
        CNI network configuration list for pods, using the reference plugins
        from `pkgs.cni-plugins`. Routing pod subnets between nodes is left to
        the host's network configuration.
        See <https://www.cni.dev/docs/spec/#network-configuration-lists>.
      '';
      example = lib.literalExpression ''
        {
          cniVersion = "1.0.0";
          name = "pods";
          plugins = [
            {
              type = "ptp";
              ipam = {
                type = "host-local";
                ranges = [ [ { subnet = "fd00:10:244:1::/64"; } ] ];
                routes = [ { dst = "::/0"; } ];
              };
            }
          ];
        }
      '';
    };
  };

  config = lib.mkIf (cfg.settings != null) {
    environment.etc."cni/net.d/05-${cfg.settings.name}.conflist".source =
      format.generate "${cfg.settings.name}.conflist" cfg.settings;

    # CRI-O loads the lexically first configuration; drop its example bridge
    # network (https://github.com/NixOS/nixpkgs/issues/406296).
    environment.etc."cni/net.d/10-crio-bridge.conflist".enable = false;
  };
}
