{ pkgs, ... }:
{
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };
  environment.systemPackages = [
    pkgs.tpm2-tools
  ];
}
