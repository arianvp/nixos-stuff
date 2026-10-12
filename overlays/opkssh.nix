final: prev: {
  # Logs in from nixbot effects with nixbot-issued ID tokens, see ./opkssh-nixbot.patch.
  opkssh = prev.opkssh.overrideAttrs (old: {
    patches = old.patches or [ ] ++ [ ./opkssh-nixbot.patch ];
  });
}
