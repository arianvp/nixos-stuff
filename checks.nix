pkgs:
let
  pkgs' = pkgs.extend (import ./overlays/spire.nix);
  inherit (pkgs) lib;

  runTest =
    path:
    pkgs'.testers.runNixOSTest {
      imports = [
        (
          { config, ... }:
          {
            globalTimeout = lib.mkDefault 120;
            meta.timeout = lib.mkDefault (config.globalTimeout + 60);
            logLevel = lib.mkDefault "warning";
          }
        )
        path
      ];
    };

  # Recursively find all _test.nix files in a directory
  # Returns list of { name, path } attrs
  findTestsIn =
    baseDir: relPath:
    let
      fullPath = baseDir + relPath;
      entries = builtins.readDir fullPath;

      processEntry =
        name: type:
        let
          newRelPath = relPath + "/${name}";
        in
        if type == "directory" then
          findTestsIn baseDir newRelPath
        else if type == "regular" && lib.hasSuffix "_test.nix" name then
          let
            testPath = baseDir + newRelPath;
            # Use the test's name attribute; tests that are functions are named after their file
            testConfig = import testPath;
            testName = testConfig.name or (lib.removeSuffix "_test.nix" name);
          in
          [
            {
              name = testName;
              path = testPath;
            }
          ]
        else
          [ ];
    in
    lib.flatten (lib.mapAttrsToList processEntry entries);

  # Find all module tests
  moduleTests = findTestsIn ./modules "";

  # Convert to attribute set of checks
  discoveredChecks = builtins.listToAttrs (
    map (test: {
      inherit (test) name;
      value = runTest test.path;
    }) moduleTests
  );
in
# Merge manually defined tests with discovered module tests
{
  spire-openbao = runTest ./tests/spire-openbao.nix;
  spire-http-challenge = runTest ./tests/spire-http-challenge.nix;
  bootloader = runTest ./modules/bootloader/test.nix;
}
// discoveredChecks
