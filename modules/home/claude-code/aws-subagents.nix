{
  config,
  lib,
  pkgs,
  ...
}:
let
  scoped-claude = pkgs.writers.writePython3Bin "scoped-claude" { flakeIgnore = [ "E501" ]; } (
    builtins.replaceStrings
      [ "@aws@" "@claude@" ]
      [ (lib.getExe pkgs.awscli2) (lib.getExe config.programs.claude-code.finalPackage) ]
      (builtins.readFile ./scoped-claude.py)
  );

  # In-session subagents share the main session's environment and
  # ~/.aws, so take their AWS access away instead.
  noAwsForSubagents = pkgs.writeShellApplication {
    name = "claude-no-aws-for-subagents";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      input=$(cat)
      if [ -z "$(jq -r '.agent_id // empty' <<<"$input")" ]; then
        exit 0
      fi
      case "$(jq -r .tool_name <<<"$input")" in
        Bash)
          jq '{
            hookSpecificOutput: {
              hookEventName: "PreToolUse",
              updatedInput: (.tool_input | .command = "export AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_EC2_METADATA_DISABLED=true; unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CONTAINER_CREDENTIALS_FULL_URI AWS_CONTAINER_CREDENTIALS_RELATIVE_URI AWS_WEB_IDENTITY_TOKEN_FILE\n" + .command)
            }
          }' <<<"$input"
          ;;
        *)
          jq -n '{
            hookSpecificOutput: {
              hookEventName: "PreToolUse",
              permissionDecision: "deny",
              permissionDecisionReason: "Subagents have no AWS access. Give AWS work to a scoped-claude worker instead; see the aws-scoped-credentials skill."
            }
          }'
          ;;
      esac
    '';
  };
in
{
  home.packages = [ scoped-claude ];

  programs.claude-code.settings.hooks.PreToolUse = [
    {
      matcher = "Bash|mcp__aws-mcp__.*";
      hooks = [
        {
          type = "command";
          command = lib.getExe noAwsForSubagents;
        }
      ];
    }
  ];
}
