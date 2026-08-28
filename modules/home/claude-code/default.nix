{
  pkgs,
  lib,
  config,
  ...
}:
{

  programs.claude-code = {
    enable = true;
    skills = {
      bump-systemd = ./skills/bump-systemd;
      jj-clone = ./skills/jj-clone;
    };

    rules.jj = ''
      YOU MUST ALWAYS USE JJ FOR VERSION CONTROL. NOT GIT.
    '';

    rules.no-comments = ''
      Avoid comments that describe things that are obvious from the code context.
      NEVER leave traces in comments about how things were before in the past.  Prose about how code changed over time belongs in commit messages ; not code.
    '';

    mcpServers.linear-server = {
      type = "http";
      url = "https://mcp.linear.app/mcp";
    };

    settings = {
      permissions = {
        allow = [
          "Bash(jj log *)"
          "Bash(jj st *)"
          "Bash(jj diff *)"
          "Bash(jj root)"
          "Bash(jj show *)"
        ];
        ask = [
          "Bash(jj git push *)"
          "Bash(gh pr create *)"
        ];
      };
    };
  };
}
