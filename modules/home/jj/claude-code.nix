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
                pkgs.coreutils
                pkgs.jq
              ];
            }
          );
        }
      ];
    }
  ];
  # Not under .claude/: Claude's sandbox mounts the project's .claude/ read-only,
  # which would make every worktree beneath it read-only too.
  worktrees = ".work";
in
{
  programs.git.ignores = [ "${worktrees}/" ];

  programs.buck2.buckconfigs."00-ignore".project.ignore = [ worktrees ];
  # Don't add worktrees to watchman's ignore_dirs: they have no .git, so watch-project
  # from inside one resolves to the parent repo's watch, which would then hide them.

  programs.claude-code = {
    rules.jj-submit = ''
      Submit changes for review with `jj stack submit [<head>]` rather than pushing
      bookmarks and opening pull requests by hand. It creates one PR per change in the
      stack and keeps them up to date on later submits. Preview with `--dry-run` first.
      Never submit a merge change made only for testing; submit each of its parents instead.
      Before working on a change that has a PR, and after a PR was merged outside
      `jj stack merge` (e.g. in the GitHub UI), run `jj stack sync <head>`.
      `jj stack merge` already syncs itself when it waits for the merge.
    '';
    rules.jj-worktrees = ''
      Worktrees are jj workspaces created by a WorktreeCreate hook. ExitWorktree cannot
      verify their state and always refuses `action: "remove"`, so pass `discard_changes: true`.
      This is safe: `jj workspace remove` snapshots the working copy before deleting it.
    '';
    rules.jj-stacking = ''
      When creating a new change, only stack it on top of another change if it logically
      depends on it. Otherwise base it on trunk (`jj new 'trunk()'`) so each change can
      be reviewed and landed independently.
      Changes that only get CI passing when combined do depend on each other: stack
      them, since none of their PRs could go green on its own.
      To test several independent changes together, create a merge change on top of
      them with `jj new <c1> <c2> <c3>` instead of stacking them on each other.
    '';
    rules.jj-rebase-mine = ''
      `jj rebase-mine` rebases all of the user's local mutable stacks onto `trunk()`.
      After running `jj git fetch`, `jj fetch`, `jj fetchm` or `jj stack merge`, offer to
      run it. `jj stack merge` only rebases the stack it merged; other stacks still need it.
      Don't run it unprompted; it rewrites every local stack.
    '';
    # Claude's worktree hooks are shaped after git, which identifies worktrees by
    # path: WorktreeCreate gets a name and must return a path, WorktreeRemove gets
    # only that path. jj identifies workspaces by name instead: `workspace add`
    # takes a path and names the workspace after its basename, `workspace remove`
    # takes only names. So remove recovers the name from the path's basename.
    settings.hooks = {
      WorktreeCreate = hook "claude-worktree-create" ''
        # Anchor at the main checkout so worktrees created from a worktree don't nest.
        # In a secondary workspace .jj/repo is a file pointing at the main .jj/repo.
        # `jj workspace root --name default` fails if that workspace has no recorded path.
        root="$(jj workspace root)"
        if [ -f "$root/.jj/repo" ]; then
          root="$(cd "$root/.jj" && realpath "$(cat repo)/../..")"
        fi
        name="$(jq -r .name)"
        dest="$root/${worktrees}/$name"
        # Remote Control recreates the worktree of each session it resumes after a
        # restart; hand back the workspace that is still there.
        if [ -d "$dest" ] && [ "$(jj -R "$root" workspace root --name "$name" 2>/dev/null)" = "$dest" ]; then
          echo "$dest"
          exit 0
        fi
        mkdir -p "$dest"
        # Commands run from another workspace leave the main checkout stale when they
        # rewrite its @, and every jj command below would then refuse to run.
        jj -R "$root" workspace update-stale >&2
        # Best effort: when offline, fall back to the last fetched trunk.
        timeout 30 jj -R "$root" git fetch >&2 || true
        # Claude counts a worktree's commits from the main checkout's git HEAD and
        # keeps worktrees with commits when the session ends. Move the main checkout
        # to trunk() so a fresh worktree doesn't start out "ahead", but only when it
        # is idle: no edits, no description, and not on top of the user's own changes.
        q() { jj -R "$root" log --no-graph -r "$1" -T change_id; }
        if [ -n "$(q '@ ~ trunk()+')" ]; then
          if [ -n "$(q '@ & empty() & description(exact:"") & children(::trunk())')" ]; then
            jj -R "$root" new 'trunk()' >&2
          else
            echo "Main checkout is not on trunk() and not idle; left it alone. This worktree will likely be kept when the session ends." >&2
          fi
        fi
        jj -R "$root" workspace add -r 'trunk()' "$dest" >&2
        echo "$dest"
      '';
      # Only refreshes remote bookmarks so trunk() is current; never moves @.
      # stdout of SessionStart hooks is injected into the context, so only the
      # rebase hint goes there.
      SessionStart = map (h: h // { matcher = "startup|resume"; }) (
        hook "claude-session-fetch" ''
          trunk() { jj --ignore-working-copy log --no-graph -r 'trunk()' -T commit_id; }
          before="$(trunk 2>/dev/null)" || exit 0
          timeout 30 jj git fetch >&2 || true
          if [ "$(trunk)" != "$before" ] &&
            [ -n "$(jj --ignore-working-copy log --no-graph -r 'mutable() & mine() ~ trunk()::' -T 'change_id ++ "\n"')" ]; then
            echo "Fetching at session start moved trunk() and some of the user's local changes are no longer based on it. Suggest running \`jj rebase-mine\`."
          fi
        ''
      );
      WorktreeRemove = hook "claude-worktree-remove" ''
        path="$(jq -r .worktree_path)"
        # WorktreeCreate puts worktrees at <main checkout>/${worktrees}/<name>.
        jj -R "$(dirname "$(dirname "$path")")" workspace remove "$(basename "$path")" >&2
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
      "Bash(jj stack submit *)"
      "Bash(jj rebase-mine*)"
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
