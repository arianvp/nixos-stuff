{ pkgs, lib }:

let
  inherit (lib) isAttrs isDerivation mapAttrs isList;

  # Helper function to recursively transform values for HCL1 canonicalization
  # Rule: If an attribute value is an attribute set, wrap it in a list
  hcl1Transform = value:
    if isAttrs value && !isDerivation value then
      # If it's an attribute set, transform it recursively and wrap in a list
      [ (mapAttrs (name: hcl1Transform) value) ]
    else if isList value then
      # If it's already a list, transform each element
      map hcl1Transform value
    else
      value;

in {

  inherit hcl1Transform;

  hcl1 = args: let json = pkgs.formats.json args; in json // {
    generate = name: value: json.generate name (mapAttrs (_: hcl1Transform) value);
  };

}
