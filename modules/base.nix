{
  pkgs,
  lib,
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

  nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) [ "claude-code" ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];

    packages = [
      pkgs.git
      pkgs.nixfmt
      pkgs.btop
      pkgs.nixd
      pkgs.go
      pkgs.binutils
      pkgs.dnsutils
      pkgs.unixtools.netstat
      pkgs.claude-code
    ];

    # Until we have a proper SSH-CA this is what we do instead
    openssh.authorizedKeys.keyFiles = [
      (pkgs.fetchurl {
        url = "https://github.com/arianvp.keys";
        sha256 = "sha256-HyJKxLYTQC4ZG9Xh91bCUVzkC1TBzvFkZR1XqT7aD7o=";
      })
    ];
  };

}
