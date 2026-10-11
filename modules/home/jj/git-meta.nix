{ config, pkgs, ... }:
let
  # jj rewrites commits on every edit, so metadata keyed on `commit:<sha>` is
  # orphaned immediately. This wrapper takes a revset where git-meta takes a
  # target and resolves it to the stable `change-id:<id>` target instead.
  jj-meta = pkgs.writeShellApplication {
    name = "jj-meta";
    runtimeInputs = [
      config.programs.jujutsu.package
      pkgs.git-meta
    ];
    text = ''
      usage() {
        cat >&2 <<EOF
      usage: jj meta <verb> <revset> [args...]   verbs: get set rm list:push list:pop set:add set:rm
             jj meta show [<revset>]             metadata on both the change-id and the commit
             jj meta <other git-meta command>    passed through, e.g. push, pull, log
      EOF
        exit 2
      }

      [ $# -ge 1 ] || usage
      verb=$1
      shift

      resolve() {
        jj log --no-graph -r "exactly($1, 1)" -T "$2"
      }

      # git-meta only discovers the repo from the cwd and ignores GIT_DIR. Going via
      # `jj git root` also covers non-colocated repos and secondary workspaces.
      # Discovery fails from inside a non-bare `.git`, so use its parent there.
      git_root=$(jj git root)
      if [ "''${git_root##*/}" = .git ]; then
        git_root=''${git_root%/.git}
      fi

      case "$verb" in
        get | set | rm | list:push | list:pop | set:add | set:rm)
          [ $# -ge 1 ] || usage
          change_id=$(resolve "$1" change_id)
          shift
          cd "$git_root"
          exec git-meta "$verb" "change-id:$change_id" "$@"
          ;;
        show)
          rev=''${1:-@}
          change_id=$(resolve "$rev" change_id)
          commit_id=$(resolve "$rev" commit_id)
          cd "$git_root"
          echo "change-id:$change_id"
          git-meta get "change-id:$change_id"
          echo "commit:$commit_id"
          git-meta get "commit:$commit_id"
          ;;
        -h | --help | help) usage ;;
        *)
          cd "$git_root"
          exec git-meta "$verb" "$@"
          ;;
      esac
    '';
  };
in
{
  home.packages = [
    pkgs.git-meta
    jj-meta
  ];
}
