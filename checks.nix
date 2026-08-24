pkgs:
let
  pkgs' = pkgs.extend (import ./overlays/spire.nix);
  inherit (pkgs) lib;

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
            # Import the test file to read its name attribute
            testConfig = import testPath;
            testName = testConfig.name or (lib.removeSuffix "_test.nix" (lib.removePrefix "/" newRelPath));
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
      value = pkgs'.testers.runNixOSTest {
        imports = [ test.path ];
      };
    }) moduleTests
  );
in
# Merge manually defined tests with discovered module tests
{
  spire-join-token = pkgs'.testers.runNixOSTest {
    imports = [ ./tests/spire-join-token.nix ];
  };
  spire-http-challenge = pkgs'.testers.runNixOSTest {
    imports = [ ./tests/spire-http-challenge.nix ];
  };
  bootloader = pkgs'.testers.runNixOSTest {
    imports = [ ./modules/bootloader/test.nix ];
  };
}
// discoveredChecks
