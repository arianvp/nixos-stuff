final: prev: {
  openssh = prev.openssh.overrideAttrs (oldAttrs: {
    buildInputs = oldAttrs.buildInputs ++ [ final.audit ];
    configureFlags = oldAttrs.configureFlags ++ [ "--with-audit=linux" ];
  });
}
