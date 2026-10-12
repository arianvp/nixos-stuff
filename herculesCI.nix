{
  self,
  unstable,
  nixbot,
}:
{ ... }:
let
  pkgs = unstable.legacyPackages.aarch64-linux;
  inherit (nixbot.lib.effects { inherit pkgs; }) mkEffect;
  altra = self.nixosConfigurations.altra;
  toplevel = altra.config.system.build.toplevel;
  audience = "OPKSSH-NIXBOT:altra";
  knownHosts = pkgs.writeText "altra-known-hosts" "altra.nixos.sh ${builtins.readFile ./hosts/altra/ssh_host_ed25519_key.pub}";
in
{
  # nixbot runs on altra, so this ssh-es to itself. switch-to-configuration runs in
  # its own unit so that it survives a restart of nixbot, which kills this effect.
  onPush.default.outputs.effects.deploy-altra = mkEffect {
    lock = "deploy-altra";
    idTokenAudiences = [ audience ];
    inputs = [
      altra.pkgs.opkssh
      pkgs.openssh
    ];
    effectScript = ''
      export HOME=$PWD OPKSSH_NIXBOT_AUDIENCE=${audience}
      opkssh login nixbot --private-key-file $HOME/id_ecdsa
      ssh -i $HOME/id_ecdsa -o UserKnownHostsFile=${knownHosts} -o StrictHostKeyChecking=yes root@altra.nixos.sh \
        "nix-env -p /nix/var/nix/profiles/system --set ${toplevel} &&
         systemd-run --wait --collect --unit=nixbot-deploy ${toplevel}/bin/switch-to-configuration switch"
    '';
  };

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
