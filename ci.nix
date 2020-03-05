builtins.mapAttrs (k: v: v.toplevel) (import ./.).deployments
