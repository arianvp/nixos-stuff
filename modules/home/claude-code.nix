{ pkgs, lib, config, ... }:
let
  worktreeCreate = pkgs.writeShellApplication {
    name = "cc-jj-worktree-create";
    runtimeInputs = with pkgs; [ jq jujutsu coreutils ];
    text = ''
      input=$(cat)
      sid=$(echo "$input" | jq -r '.session_id')
      cwd=$(echo "$input" | jq -r '.cwd')
      ws="$cwd/.work/cc-$sid"
      mkdir -p "$cwd/.work"
      (cd "$cwd" && jj workspace add --name "cc-$sid" "$ws" >&2)
      echo "$ws"
    '';
  };
  worktreeRemove = pkgs.writeShellApplication {
    name = "cc-jj-worktree-remove";
    runtimeInputs = with pkgs; [ jq jujutsu coreutils ];
    text = ''
      input=$(cat)
      sid=$(echo "$input" | jq -r '.session_id')
      cwd=$(echo "$input" | jq -r '.cwd')
      (cd "$cwd" && jj workspace forget "cc-$sid" 2>/dev/null) || true
      rm -rf "$cwd/.work/cc-$sid"
    '';
  };

in
{
  home.file.".claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoRoot}/modules/home/claude-code/skills";

  programs.claude-code = {
    enable = true;
    settings = {
      sandbox = {
        # TODO: Buggy as fuck because Antrophics has no software engineers and couldn't make a bugless program if their lives depended on it:
        # https://github.com/anthropics/claude-code/issues/52525
        enabled = false;
        failIfUnavailable = true;
        filesystem = {
          denyWrite = [ "/" ];
          denyRead = [ "/" ];
          allowRead = [
            "."
            "/nix/store"
            "/nix/var/nix/daemon-socket/socket"
          ];
          allowWrite = [
            "."
            "/nix/var/nix/daemon-socket/socket"
          ];
        };
        network = {
          allowUnixSockets = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [ "/nix/var/nix/daemon-socket/socket" ];
          allowAllUnixSockets = pkgs.stdenv.hostPlatform.isLinux;
          allowedDomains = [
            "cache.nixos.org"
            "channels.nixos.org"
          ];
        };
      };
      permissions = {
        allow = [
          "Bash(jj log)"
          "Bash(jj st)"
          "Bash(jj diff)"
          "Bash(jj root)"
          "Bash(jj show)"
        ];
        ask = [
          "Bash(jj git push *)"
          "Bash(gh pr create *)"
        ];
      };
      autoMode.environment = [
        "$defaults"
        ''
        **Secrets management**:
        When there is a need for a long-lived secret, this MUST be stored in a Secure Element like Apple's Secure Enclave, Yubikey or TPM.
        We NEVER store long-lived secrets in plain-text. Public key cryptography MUST be preferred over shared secrets. Internal services MUST use SPIFFE / SPIRE for authentication.
        ''
        ''
        **Internal package registry**: All external dependencies MUST be defined in flake.nix. NEVER add new flake inputs without asking.
        NEVER add trusted-substituters without asking. https://cache.nixos.org is trusted.  https://channels.nixos.org/ is trusted. https://github.com/NixOS/nixpkgs is trusted.
        ''
      ];
      mcpServers = {
        linear = {
          type = "sse";
          url = "https://mcp.linear.app/sse";
        };
      };
      hooks = {
        WorktreeCreate = [{
          hooks = [{
            type = "command";
            command = lib.getExe worktreeCreate;
          }];
        }];
        WorktreeRemove = [{
          hooks = [{
            type = "command";
            command = lib.getExe worktreeRemove;
          }];
        }];
      };
    };
  };
}
