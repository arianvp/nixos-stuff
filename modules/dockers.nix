let
  tagFromPackage = drv: drv.passthru.imageTag;
  imageOptions =
    {
      name,
      pkgs,
      config,
      ...
    }:
    {
      options = {
        image = mkOption {
          type = package;
        };
        contents = mkOption {
          type = listOf package;
        };
      };
      config = mkMerge [
        rec {
          image = pkgs.buildLayeredImage {
            inherit name;
            inherit contents;
          };
          tag = image.passthru.imageTag;
        }
      ];
    };
in
{
  options = {
    docker.images = mkOption {
      type = attrsOf (submodule imageOptions);
    };
  };

  config = {
  };
}
