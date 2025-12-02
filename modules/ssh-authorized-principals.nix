{ config, lib, ... }:

with lib;

let
  cfg = config.services.openssh;
in
{
  options.services.openssh.authorizedPrincipals = mkOption {
    type = types.attrsOf (types.listOf types.str);
    default = {};
    description = ''
      Authorized principals for SSH certificate authentication.
      Maps usernames to lists of principals they can authenticate as.

      Example:
        services.openssh.authorizedPrincipals = {
          root = [ "arian" "flokli" ];
          arian = [ "arian" ];
          flokli = [ "flokli" ];
        };
    '';
  };

  config = {
    # Ensure AuthorizedPrincipalsFile is set correctly
    services.openssh.settings.AuthorizedPrincipalsFile =
      mkDefault "/etc/ssh/authorized_principals.d/%u";

    # Generate environment.etc entries for each user's authorized principals
    # Setting mode forces NixOS to copy the file instead of symlinking to /nix/store.
    # Without this, sshd rejects the file with:
    # "Ignored authorized principals: bad ownership or modes for directory /nix/store"
    # because /nix/store is group-writable (1775) which violates sshd's strict path checks.
    environment.etc = mapAttrs' (user: principals:
      nameValuePair "ssh/authorized_principals.d/${user}" {
        text = concatStringsSep "\n" principals + "\n";
        mode = "0644";
      }
    ) cfg.authorizedPrincipals;
  };
}
