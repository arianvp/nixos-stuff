{
  lib,
  fetchurl,
  linkFarm,
  runCommand,
  unzip,
  writers,
  iam-policy-autopilot,
}:
let
  autopilot = lib.getExe iam-policy-autopilot;

  edits = {
    aws-iam."references/aws-iam-policy-generation.md" = {
      replace."uvx iam-policy-autopilot@latest" = autopilot;
      sections."### 1. Verify Autopilot Availability" = ''
        IAM Policy Autopilot is installed through Nix at `${autopilot}`. Always
        run it by that exact path, and never install it or anything to run it
        with.

        ```bash
        ${autopilot} --version
        ```

        If this fails, retry once, then fall back to the Service Authorization
        Reference path (Task 3). Once it succeeds, proceed with Task 1b.
      '';
      sections."### Autopilot not found" = ''
        Autopilot comes from Nix at `${autopilot}` and is always there. If it
        fails to run, fall back to the Service Authorization Reference path.
      '';
    };
  };

  editSkill = writers.writePython3 "edit-skill" { flakeIgnore = [ "E501" ]; } ./edit-skill.py;

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
        edits = builtins.toJSON (edits.${name} or { });
        passAsFile = [ "edits" ];
      }
      ''
        mkdir $out
        unzip -q $src -d $out
        ${editSkill} $out $editsPath
        if grep -RnwF uvx $out; then
          echo "${name} tells the agent to use uvx; add an edit that makes it use a Nix package" >&2
          exit 1
        fi
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
