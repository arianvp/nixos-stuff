{
  pkgs,
  lib,
  config,
  ...
}:
{

  imports = [
    ./watchman.nix
    ./nix.nix
    ./go.nix
  ];

  programs.jujutsu = {
    enable = true;
    settings = {
      ui.default-command = "st";
      aliases.fetch-pr =
        let
          fetch-pr = pkgs.writeShellApplication {
            name = "fetch-pr";
            runtimeInputs = [
              pkgs.gh
              config.programs.jujutsu.package
              pkgs.jq
            ];
            text = ''
              pr="$1"
              read -r branch owner repo_url < <(
                gh pr view "$pr" \
                  --json headRefName,headRepositoryOwner,headRepository \
                  --jq '[.headRefName, .headRepositoryOwner.login, ("https://github.com/" + .headRepository.nameWithOwner)] | @tsv'
              )
              jj git remote add "$owner" "$repo_url" 2>/dev/null || true
              jj git fetch --remote "$owner" -b "$branch"
            '';
          };
        in
        [
          "util"
          "exec"
          "--"
          "gh pr checkout --detach"
        ];

      # ui.default-command = "log";
      user.name = "Arian van Putten";
      user.email = "arian@arianvp.me";
      # templates.git_push_bookmark = ''"arianvp/push-" ++ change_id.short()'';
      snapshot.auto-track = "none()";
      signing = {
        behavior = "drop";
        backend = "ssh";
        # TODO: point to whatever yubikey is inserted. I wonder if we can do this with udev
        # key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJfMczLTlN0csX8HFFneaYW6OH0lupwCryoDANaqR6lxAAAABHNzaDo=";
        key = "~/.ssh/id_ed25519_sk";
      };
      # git.sign-on-push = true;

    };
  };
}
