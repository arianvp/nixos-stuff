{
  programs.claude-code = {
    settings.sandbox.fileSystem = {
      allowRead = [ "~/.config/jj/" ];
    };
    settings.permissions.ask = [
      "Bash(jj git push *)"
      "Bash(jj gerrit *)"
      "Bash(jj op abandon *)"
      "Bash(jj op integrate *)"
      "Bash(jj op restore *)"
      "Bash(jj op revert *)"
      "Bash(jj bookmark forget)"
      "Bash(jj bookmark delete)"
      "Bash(jj workspace forget)"
      "Bash(jj config set *)"
    ];
  };
}
