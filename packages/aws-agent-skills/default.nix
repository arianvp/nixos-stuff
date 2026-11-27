{
  lib,
  fetchurl,
  linkFarm,
  runCommand,
  unzip,
  writers,
}:
let
  skill =
    name:
    { version, sha256 }:
    runCommand "aws-skill-${name}-${version}"
      {
        src = fetchurl {
          name = "${name}-${version}.zip";
          url = "https://agent-toolkit.us-east-1.api.aws/skills/${name}/versions/${version}/files/download";
          inherit sha256;
        };
        nativeBuildInputs = [ unzip ];
      }
      ''
        mkdir $out
        unzip -q $src -d $out
      '';

  skills = lib.mapAttrs skill (lib.importJSON ./skills.json);
in
(linkFarm "aws-agent-skills" skills).overrideAttrs {
  passthru = {
    inherit skills;
    updateScript = writers.writePython3Bin "aws-agent-skills-update" {
      flakeIgnore = [ "E501" ];
    } ./update.py;
  };
}
