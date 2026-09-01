{
  programs.claude-code = {
    settings.sandbox.fileSystem = {
      allowRead = [ "~/.config/jj/" ];
    };
    settings.permissions.ask = [
      "Bash(jj git push *)"
      "Bash(jj gerrit *)"
      "Bash(jj op *)"
      "Bash(jj op *)"
      "Bash(jj bookmark forget)"
      "Bash(jj bookmark delete)"
      "Bash(jj workspace forget)"
      "Bash(jj config set *)"
    ];
  };
}
