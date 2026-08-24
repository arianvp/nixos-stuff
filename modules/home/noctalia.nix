{ ... }:
{
  programs.noctalia = {
    systemd.enable = true;
    settings = {
    };
    # this may also be a raw TOML string or a path to a TOML file.
  };
}
