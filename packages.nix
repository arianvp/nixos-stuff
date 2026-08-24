pkgs:
let
  pkgs' = pkgs.extend (
    pkgs.lib.composeManyExtensions [
      (import ./overlays/spire.nix)
      (import ./overlays/he-ddns.nix)
    ]
  );
in
{
  inherit (pkgs')
    spire-controller-manager
    spire-tpm-plugin
    spire
    he-ddns
    ;
}
