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

  images = map (
    img:
    let
      imageSpec = import img.path;
      pulledImage = pkgs.dockerTools.pullImage imageSpec;
    in
    {
      inherit pulledImage;
      inherit (imageSpec) finalImageName finalImageTag imageDigest;
    }
  ) imageDirs;
in
{
  systemd.services = lib.listToAttrs (
    map (
      image:
      lib.nameValuePair "registry-push-${utils.escapeSystemdPath "${image.finalImageName}:${image.finalImageTag}"}" {
        description = "Push ${image.finalImageName}:${image.finalImageTag} to registry";
        requiredBy = [ "multi-user.target" ];
        after = [ "docker-registry.service" ];
        requires = [ "docker-registry.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
          ExecStart = "${pkgs.skopeo}/bin/skopeo copy --insecure-policy --dest-tls-verify=false --preserve-digests docker-archive:${image.pulledImage} docker://localhost:5000/${image.finalImageName}:${image.finalImageTag}";
        };
      }
    ) images
  );
}
