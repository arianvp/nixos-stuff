#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq git
git ls-remote -h https://github.com/nixos/nixpkgs-channels  | column --table-columns rev,ref --json -d | jq '.table | map(.["value"] = (. | .url = "https://github.com/nixos/nixpkgs-channels") | .["key"] = (.ref | split("/")[2]) | del (.rev, .ref)) | from_entries' > nixpkgs.json
