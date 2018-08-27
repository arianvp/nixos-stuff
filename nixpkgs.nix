{ nixpkgs ? import <nixpkgs> }:
let
  isDir = path: builtins.pathExists (path + "/.");
  overlays = path:
    if isDir path 
    then
      let
        content = builtins.readDir path;
      in
        map (n: import (path + ("/" + n)))
            (builtins.filter (n: builtins.match ".*\\.nix" n != null || builtins.pathExists (path + ("/" + n + "/default.nix")))
                    (builtins.attrNames content))
    else
      import path;
in
  nixpkgs { overlays = overlays ./overlays; }
