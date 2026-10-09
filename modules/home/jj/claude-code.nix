{
  config,
  lib,
  pkgs,
  ...
}:
let
  hook = name: text: [
    {
      hooks = [
        {
          type = "command";
          command = lib.getExe (
            pkgs.writeShellApplication {
              inherit name text;
              runtimeInputs = [
                config.programs.jujutsu.package
                pkgs.jq
              ];
            }
          );
        }
      ];
    }
  ];
in
{
  programs.git.ignores = [ ".claude/worktrees/" ];

  programs.claude-code = {
    rules.jj-worktrees = ''
      Worktrees are jj workspaces created by a WorktreeCreate hook. ExitWorktree cannot
      verify their state and always refuses `action: "remove"`, so pass `discard_changes: true`.
      This is safe: `jj workspace remove` snapshots the working copy before deleting it.
    '';
    # Claude's worktree hooks are shaped after git, which identifies worktrees by
    # path: WorktreeCreate gets a name and must return a path, WorktreeRemove gets
    # only that path. jj identifies workspaces by name instead: `workspace add`
    # takes a path and names the workspace after its basename, `workspace remove`
    # takes only names. So remove recovers the name from the path's basename.
    settings.hooks = {
      WorktreeCreate = hook "claude-worktree-create" ''
        dest="$(jj workspace root)/.claude/worktrees/$(jq -r .name)"
        mkdir -p "$dest"
        jj workspace add "$dest" >&2
        echo "$dest"
      '';
      WorktreeRemove = hook "claude-worktree-remove" ''
        jj workspace remove "$(jq -r '.worktree_path | split("/") | last')" >&2
      '';
    };
    settings.sandbox.filesystem = {
      allowRead = [
        "~/.config/jj/"
        "~/.config/git/"
        # WARNING: this exposes the GitHub token to the sandbox if it lives on disk.
        #
        # git's credential helper for github.com is `gh auth git-credential`,
        # which needs to read this directory. config.yml is managed by
        # home-manager (programs.gh) and harmless, but hosts.yml is written by
        # `gh auth login`. On macOS gh normally keeps the token in the Keychain
        # and hosts.yml only holds the username. If keyring storage failed at
        # login time, hosts.yml contains the token in plaintext and anything
        # running in the sandbox can read it. Check with `gh auth status`: it
        # should say "(keyring)", not "(<path>/hosts.yml)".
        #
        # Even with the Keychain, the Seatbelt sandbox may deny access to it,
        # in which case auth still fails here. The proper fix is to have the
        # sandbox proxy inject credentials (sandbox.credentials) so the token
        # never needs to be readable from inside the sandbox; remove this entry
        # once that works.
        "~/.config/gh/"
      ];
    };
    settings.permissions.ask = [
      "Bash(jj git push *)"
      "Bash(jj gerrit *)"
      "Bash(jj op abandon *)"
      "Bash(jj op integrate *)"
      "Bash(jj op restore *)"
      "Bash(jj op revert *)"
      "Bash(jj bookmark forget)"
      "Bash(jj bookmark delete)"
      "Bash(jj workspace forget)"
      "Bash(jj config set *)"
    ];
  };
}
