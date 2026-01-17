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
    ./ssh.nix
  ];

  documentation.man = {
    enable = true;
    generateCaches = true;
  };

  nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) [ "claude-code" ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = false;
    vimAlias = false;
  };

  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "wheel" "nix-trusted-users" ];
    packages = [
      pkgs.git
      pkgs.nixfmt
      pkgs.jujutsu
      pkgs.jjui
      pkgs.btop
      pkgs.nixd
      pkgs.go
      pkgs.binutils
      pkgs.dnsutils
      pkgs.unixtools.netstat
      pkgs.claude-code
    ];
  };
}
