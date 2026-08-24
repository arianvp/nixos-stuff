{ ... }:
{
  imports = [ ./common.nix ];

  nix.settings = {
    experimental-features = [
      "cgroups"
      "auto-allocate-uids"
    ];

    allowed-users = [ "@nix-trusted-users" ];
    trusted-users = [ "@nix-trusted-users" ];

    system-features = [ "uid-range" ];
    auto-allocate-uids = true;
    use-cgroups = true;
  };

  nix.gc.dates = [ "13:00" ];

  users.groups.nix-trusted-users = { };
}
