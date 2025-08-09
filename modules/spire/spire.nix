{
  options = {
    spire.trustDomain = lib.mkOption {
      type = lib.types.str;
      description = "Trust domain for SPIRE";
    };
  };
}
