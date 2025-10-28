self: super: {
  claude-code = super.claude-code.overrideAttrs (oldAttrs: rec {
    version = "2.0.24";
    src =  self.fetchzip {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-pi8EdN/XyzMGWBcTiV8pr9GODcBs0uPFarWjQMoCaEs=";
    };
    npmDepsHash = "sha256-XylBq0/zu7iSTPiLAkewQFeh1OmtJv9nUfnCb66opVE=";
  });
}
