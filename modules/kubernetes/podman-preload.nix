{
  utils,
  pkgs,
  lib,
  ...
}:
let
  # Recursively find only leaf directories (those with default.nix) in images/
  findImageDirs =
    dir:
    let
      contents = builtins.readDir dir;
      entries = lib.mapAttrsToList (
        name: type:
        let
          path = dir + "/${name}";
        in
        if type == "directory" then
          if builtins.pathExists (path + "/default.nix") then
            [ { inherit path name; } ]
          else
            findImageDirs path
        else
          [ ]
      ) contents;
    in
    lib.flatten entries;

  imageDirs = findImageDirs ./images;

  images = map (img: (pkgs.dockerTools.pullImage (import img.path))) imageDirs;
in
{

  systemd.services = lib.listToAttrs (
    map (
      image:
      lib.nameValuePair "podman-load-${utils.escapeSystemdPath image.imageDigest}" {
        description = "Load ${image}";
        wantedBy = [ "crio.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StandardInput = "file:${image}";
          ExecStart = "${pkgs.podman}/bin/podman load";
        };
      }
    ) images
  );
}
