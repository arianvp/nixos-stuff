# Overlays

Contains any custom package definitions. Which I should probably upstream sometime

## Bumping a nixpkgs package early

When an overlay bumps a package to a version nixpkgs doesn't have yet, wrap it
in `preferNewer` from [lib.nix](./lib.nix). Once nixpkgs catches up, it falls back
to the nixpkgs package and warns that the override can be removed. See
[awscli2.nix](./awscli2.nix).
