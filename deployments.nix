self: super: 
  # makes sure that all nix commands use our pinned nixpkgs
  let 
    # TODO: filterSource the nixPath for unwanted rebuilds
    config = x: { imports = [ x ]; config.nix.nixPath = [ "nixpkgs=${./.}" ]; }; 
    install = deployment: super.writeScriptBin "install-it"
    ''
      set -e
      set -x
      mkdir /mnt/etc
      touch /mnt/etc/NIXOS
      ${deployment.nixos-enter}/bin/nixos-enter --root /mnt -- nix-env --set /nix/var/nix/profiles/system ${deployment.toplevel}
    '';
    # TODO Extract this to a nice reusable piece of nix for others to use
    deploy = deployment: super.writeScriptBin "deploy" 
    ''
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
          ssh $SSHOPTS "$remote" "$@"
        fi
      }
      remoteOrLocal sudo nix-env --profile "$profile" --set "${deployment.toplevel}" --show-trace
      remoteOrLocal sudo "$profile/bin/switch-to-configuration" "$action"
    '';
  in {
    deployments = {
      "old.arianvp.me" = deploy (super.nixos (config ./configs/arianvp.me.bak));
      "arianvp-me" = deploy (super.nixos (config ./configs/arianvp.me));
      "ryzen" =  deploy (super.nixos (config ./configs/ryzen));
      "t430s" =  (super.nixos (config ./configs/t430s));
      "t490s" = deploy (super.nixos (config ./configs/t490s));
    };
    digitalocean-image = (super.nixos (config ./modules/digitalocean/image.nix )).digitalOceanImage;
    arianvp-website = ./website;
}
