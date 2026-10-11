pkgs:
let
  pkgs' = pkgs.extend (pkgs.lib.composeManyExtensions (import ../overlays));
in
{
  inherit (pkgs')
    spire-controller-manager
    spire-tpm-plugin
    spire
    he-ddns
    jj-stack
    git-meta
    ;
}
