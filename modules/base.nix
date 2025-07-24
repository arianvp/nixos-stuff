{
  pkgs,
  ...
}:
{
  imports = [
    ./diff.nix
    ./dnssd.nix
    ./monitoring.nix
    ./nix.nix
  ];

  services.openssh.settings.PasswordAuthentication = false;

  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "@wheel" ];

    # Until we have a proper SSH-CA this is what we do instead
    openssh.authorizedKeys.keyFiles = [
      (pkgs.fetchurl {
        url = "https://github.com/arianvp.keys";
        sha256 = "sha256-HyJKxLYTQC4ZG9Xh91bCUVzkC1TBzvFkZR1XqT7aD7o=";
      })
    ];
  };

}
