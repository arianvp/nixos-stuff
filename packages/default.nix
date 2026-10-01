pkgs:
let
  pkgs' = pkgs.extend (
    pkgs.lib.composeManyExtensions [
      (import ../overlays/spire.nix)
      (import ../overlays/he-ddns.nix)
    ]
  );
in
{
  jj-stack = pkgs.callPackage ./jj-stack/package.nix { };
  inherit (pkgs')
    spire-controller-manager
    spire-tpm-plugin
    spire
    he-ddns
    ;
}
