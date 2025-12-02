{ config, lib, ... }:
let
  cfg = config.services.openssh;
in
{
  options.services.openssh.authorizedPrincipals = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = {};
  };

  config = {
    services.openssh.settings.AuthorizedPrincipalsFile = "/etc/ssh/authorized_principals.d/%u";
    environment.etc = lib.mapAttrs' (user: principals:
      lib.nameValuePair "ssh/authorized_principals.d/${user}" {
        text = lib.concatStringsSep "\n" principals;
        mode = "0644";
      }
    ) cfg.authorizedPrincipals;
  };
}
