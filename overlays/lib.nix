lib: {
  /**
    Use `override` until nixpkgs' `pkg` is at least as new.

    Once it is, returns `pkg` and warns, at the line that sets the override's
    `version`, that the override is dead code.

    # Example

    ```nix
    awscli2 = preferNewer prev.awscli2 (prev.awscli2.overrideAttrs { version = "2.42.4"; ... });
    ```
  */
  preferNewer =
    pkg: override:
    let
      pos = builtins.unsafeGetAttrPos "version" override;
    in
    if lib.versionAtLeast pkg.version override.version then
      lib.warn "${pos.file}:${toString pos.line}: ${pkg.pname} ${pkg.version} in nixpkgs is at least ${override.version}; remove this override" pkg
    else
      override;
}
