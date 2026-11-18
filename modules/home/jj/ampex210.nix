{ pkgs, ... }:
let
  # The 210 draws line graphics from the letters a to o between ESC $ and
  # ESC % (appendix C of its manual). jj's curved graph uses the box drawing
  # that maps onto them, so each run of it is swapped for a run of letters.
  #
  # TODO: fix this in jj instead. Its graph characters are fixed per
  # ui.graph.style; an option to set them, escapes included, would make this
  # filter unnecessary and leave the pager plain less -FrXK.
  graphics = {
    "╰" = "a";
    "╭" = "b";
    "╮" = "c";
    "╯" = "d";
    "└" = "e";
    "┌" = "f";
    "┐" = "g";
    "┘" = "h";
    "┼" = "i";
    "│" = "j";
    "─" = "k";
    "┤" = "l";
    "├" = "m";
    "┬" = "n";
    "┴" = "o";
  };
  boxes = builtins.concatStringsSep "|" (builtins.attrNames graphics);
  letters = builtins.concatStringsSep " " (
    pkgs.lib.mapAttrsToList (box: letter: "-e 's/${box}/${letter}/g'") graphics
  );
in
{
  # less -R ends every line with ESC [ m, whatever the terminfo entry says;
  # -r passes the graphics escapes through and sends nothing of its own.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "jj-ampex210-pager";
      runtimeInputs = [
        pkgs.gnused
        pkgs.less
      ];
      text = ''
        LC_ALL=C sed -E -e 's/((${boxes})+)/\x1b$\1\x1b%/g' ${letters} | less -FrXK
      '';
    })
  ];
}
