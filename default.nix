let 
  # nixpkgs = import <nixpkgs>; # TODO make this a reproducible version
  channels = builtins.fromJSON (builtins.readFile ./nixpkgs.json);
  nixpkgs = import (builtins.fetchGit {
    name = "stable-tracker-update";
    url = "https://github.com/worldofpeace/nixpkgs";
    rev = "a0e8dfd1863d1b65eeea6ce952581034b54600f5";
    ref = "stable-tracker-update";
  });
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
in nixpkgs { overlays = overlays ./overlays; config = { allowUnfree = true; }; }
