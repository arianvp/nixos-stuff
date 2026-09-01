{
  pkgs,
  lib,
  config,
  ...
}:
{

  #
  home.packages = [
    pkgs.socat
    pkgs.bubblewrap
    pkgs.ripgrep
  ];

  programs.git.ignores = [ ".claude/settings.local.json" ];
  programs.claude-code = {
    enable = true;
    skills = {
      bump-systemd = ./skills/bump-systemd;
      jj-clone = ./skills/jj-clone;
    };

    rules.jj = ''
      YOU MUST ALWAYS USE JJ FOR VERSION CONTROL. NOT GIT.
    '';

    rules.no-comments = ''
      Avoid comments that describe things that are obvious from the code context.
      NEVER leave traces in comments about how things were before in the past.  Prose about how code changed over time belongs in commit messages ; not code.
    '';

    mcpServers.linear-server = {
      type = "http";
      url = "https://mcp.linear.app/mcp";
    };

    settings = {
      sandbox = {
        enabled = true;
        failIfUnavailable = true;
        # this also blocks ! commands (undocumented)
        allowUnsandboxedCommands = false;
        filesystem = {
          denyRead = [
            # Lets be restrictive. No need to nose around my home directory ever.
            # Linux is a wild-west and credentials are sprawled all over it
            "~/"
            # Forces a local chroot store in ~/.local/share/nix/root store in lix
            "/nix/var/nix"
          ];

          # TODO: On MacOS allow reading /nix/var/nix/daemon/socket as it doesn't allow local chroot stores

          # needed for accessing the local chroot store and flake fetches
          allowWrite = [
            "~/.local/share/nix"
            "~/.cache/nix"
          ];
        };

        network = {
          allowedDomains = [
            "api.github.com"
            "channels.nixos.org"
            "cache.nixos.org"
            "nixos.snix.store"
          ];
          # injects NIX_SSL_CERT_FILE too so it works! :party:
          tlsTerminate = { };
        };
        # TODO: Figure out a way to make the sandbox talk to flatpak secret portal to get gh auth token injected.
        # storing the gh token on disk insecurely is not a satisfying workaround.
        credentials = {
        };
      };
      permissions.ask = [
        # http://code.claude.com/docs/en/sandboxing#the-unsandboxed-retry-escape-hatch
        # though shouldn't be needed when allowUnsandboxedCommands = false
        "Bash(dangerouslyDisableSandbox:true)"
      ];
    };
  };
}
