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

  gitDenyResponse = pkgs.writeText "claude-git-deny.json" (builtins.toJSON {
    hookSpecificOutput = {
      hookEventName = "PreToolUse";
      permissionDecision = "deny";
      permissionDecisionReason = ''
        git is not available in this environment. This repo uses jj (Jujutsu).

        Use jj instead:
          jj log             - history
          jj st              - status
          jj diff            - working-copy diff
          jj show <rev>      - inspect a commit
          jj file list <rev> - list files at a revision
          jj file show <rev> <path> - file contents at a revision
          jj help            - full command list

        Do NOT retry the same command via git, git -C, git --git-dir, etc. - they are all denied.
      '';
    };
  });
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
        deny = [ "Bash(git *)" ];
        allow = [
          "Bash(jj log)"
          "Bash(jj st)"
          "Bash(jj diff)"
          "Bash(jj root)"
          "Bash(jj show)"
        ];
      };
      hooks = {
        PreToolUse = [{
          matcher = "Bash";
          hooks = [{
            type = "command";
            "if" = "Bash(git *)";
            command = "cat ${gitDenyResponse}";
          }];
        }];
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
