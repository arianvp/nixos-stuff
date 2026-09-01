{ lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.sessionVariables.SSH_SK_PROVIDER = "/usr/lib/ssh-keychain.dylib";

  home.sessionPath = [
    "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
  ];

  programs.zsh.profileExtra = ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
  '';
}
