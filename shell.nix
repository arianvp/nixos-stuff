let 
  pkgs = import ./.;
in
  pkgs.mkShell {
    name = "Shell";
   buildInputs = with pkgs; [ (terraform.withPlugins (p: [p.digitalocean])) ];
  }
