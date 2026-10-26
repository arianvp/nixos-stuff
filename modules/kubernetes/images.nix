{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes;

  imageName = image: "${image.imageName}:${image.imageTag}";

  pause = pkgs.runCommandCC "pause-${pkgs.kubernetes.version}" { } ''
    mkdir -p $out/bin
    $CC -Os -Wall -Werror -DVERSION=v${pkgs.kubernetes.version} \
      -o $out/bin/pause ${pkgs.kubernetes.src}/build/pause/linux/pause.c
  '';
in
{
  options.kubernetes = {
    images = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Container images built with `pkgs.dockerTools` to load into CRI-O's
        storage, so that pods can use them without a registry. They are pinned,
        so the kubelet does not garbage collect them.
      '';
    };

    pauseImage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dockerTools.buildLayeredImage {
        name = "localhost/pause";
        tag = pkgs.kubernetes.version;
        config.Entrypoint = [ "${pause}/bin/pause" ];
      };
      defaultText = lib.literalMD "an image of `pause` built from the Kubernetes source";
      description = "Image for the infrastructure container of pods.";
    };
  };

  config = lib.mkIf cfg.kubelet.enable {
    kubernetes.images = [ cfg.pauseImage ];

    virtualisation.cri-o.pauseImage = imageName cfg.pauseImage;
    virtualisation.cri-o.settings.crio.image.pinned_images = map imageName cfg.images;

    systemd.services.kubernetes-images = {
      description = "Load container images for Kubernetes";
      wantedBy = [ "crio.service" ];
      before = [ "crio.service" ];
      restartTriggers = cfg.images;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = map (
          image:
          "${lib.getExe pkgs.skopeo} copy --quiet docker-archive:${image} containers-storage:${imageName image}"
        ) cfg.images;
      };
    };
  };
}
