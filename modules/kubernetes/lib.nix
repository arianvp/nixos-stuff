{ lib }:
{
  # Command-line flags, rendered with lib.cli.toCommandLineShellGNU. Lists are
  # joined with commas, which is how all Kubernetes components take list flags.
  argsType = lib.types.attrsOf (
    lib.types.nullOr (
      lib.types.coercedTo (lib.types.listOf lib.types.str) (lib.concatStringsSep ",") (
        lib.types.oneOf [
          lib.types.str
          lib.types.int
          lib.types.bool
          lib.types.path
        ]
      )
    )
  );

  # Booleans are passed as --flag=true/false so that false overrides defaults
  # that are true (e.g. --leader-elect) instead of omitting the flag.
  toArgs =
    args:
    lib.cli.toCommandLineShellGNU { } (
      lib.mapAttrs (_: v: if lib.isBool v then lib.boolToString v else v) args
    );
}
