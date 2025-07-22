{ pkgs, ... }:
{
  imports = [
    ./dnssd.nix
    ./monitoring.nix
  ];

  services.openssh.settings.PasswordAuthentication = false;

  environment.systemPackages = [ pkgs.direnv ];
  programs.bash.interactiveShellInit = ''
    eval "$(direnv hook bash)"
  '';

  nix.settings.trusted-users = [
    "@wheel"
    "@nix-trusted-users"
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "fetch-closure"
  ];

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
