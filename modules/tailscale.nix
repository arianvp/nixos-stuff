{ pkgs, lib, ... }:
{
  options.tailnet.name = lib.mkOption {
    type = lib.types.string;
    default = "bunny-minnow.ts.net";
  };

  config = {
    services.tailscale.enable = true;
  };
}
