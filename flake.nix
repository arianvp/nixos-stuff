{
  description = "A very basic flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/release-20.09";

  outputs = { self, nixpkgs }: {

    overlays = {
      fonts = import ./overlays/fonts.nix;
      wire = import ./overlays/wire.nix;
      neovim = import ./overlays/neovim.nix;
      user-environment = import ./overlays/user-environment.nix;
    };

    nixosModules = {
      kubernetes = import ./modules/kubernetes.nix;
      containerd = import ./modules/kubernetes.nix;
    };

    nixosConfigurations =
      with import nixpkgs
        {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = nixpkgs.lib.attrValues self.overlays;
        };
      let
        nixos' = config:
          let deployment = nixos config; in
          deployment // {
            deploy = writeScript "deploy" ''
              set -e
              tmpDir=$(mktemp -t -d nixos-rebuild.XXXXXX)
              SSHOPTS="$NIX_SSHOPTS -o ControlMaster=auto -o ControlPath=$tmpDir/ssh-%n -o ControlPersist=60"
              cleanup() {
                  for ctrl in "$tmpDir"/ssh-*; do
                      ssh -o ControlPath="$ctrl" -O exit dummyhost 2>/dev/null || true
                  done
                  rm -rf "$tmpDir"
              }
              trap cleanup EXIT

              profile=/nix/var/nix/profiles/system
              action="$1"
              remote="''${2:-local}"

              if [ "$remote" != "local" ]; then
                store="ssh://$remote"
                NIX_SSHOPTS=$SSHOPTS nix copy --no-check-sigs --to "$store" "${deployment.toplevel}"
              fi

              remoteOrLocal() {
                if [ "$remote" == "local" ]; then
                  "$@"
                else
                  ssh $SSHOPTS -t "$remote" "$@"
                fi
              }
              remoteOrLocal sudo nix-env --profile "$profile" --set "${deployment.toplevel}" --show-trace
              remoteOrLocal sudo "$profile/bin/switch-to-configuration" "$action"
            '';
          };
      in
      {
        ryzen = nixos' ./configs/ryzen;
        t490s = nixos' ./configs/t490s;
        arianvp-me = nixos' ./configs/arianvp.me;
      };
  };
}
