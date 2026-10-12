{
  self,
  unstable,
  nixbot,
}:
{ ... }:
let
  pkgs = unstable.legacyPackages.aarch64-linux;
  inherit (nixbot.lib.effects { inherit pkgs; }) mkEffect;
  toplevel = self.nixosConfigurations.altra.config.system.build.toplevel;
in
{
  # onEvent is evaluated from the default branch, so `toplevel` here is master's.
  onEvent.pull_request.nvd-altra = mkEffect {
    # Evaluates the PR's Nix code.
    when.permission = "write";
    lock = "nvd-altra-{pr}";
    checkout = true;
    inputs = [
      pkgs.nix
      pkgs.nvd
    ];
    effectScript = ''
      head=$(nix --extra-experimental-features 'nix-command flakes' build --no-link --print-out-paths \
        .#nixosConfigurations.altra.config.system.build.toplevel)
      {
        echo '### `altra`: `nvd diff master PR`'
        echo '```'
        nvd diff ${toplevel} "$head" | head -c 60000
        echo '```'
      } | nixbot-pr-comment --replace-marker nvd-altra
    '';
  };
}
