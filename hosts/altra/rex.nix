rex:
{
  imports = [ rex.nixosModules.default ];

  services.rex.loginServer = {
    enable = true;
    # Any user device on the tailnet may act as arian; tagged devices may not.
    accounts.arian.principals = [ "tailscale:*" ];
    tailscaleServe.enable = true;
  };
}
