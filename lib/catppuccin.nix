# Catppuccin Mocha palette — the single source of truth for every themed
# config in this repo. Hex values are lowercase WITHOUT the leading '#';
# consumers add the prefix or convert to their own format (0xAARRGGBB for
# SketchyBar, bare hex for fish).
#
# Consumers:
#   - modules/home/fish.nix        (fish_color_* / fish_pager_color_*)
#   - modules/home/xdg-files.nix   (starship.toml palette table, kitty theme)
#   - modules/home/pi.nix          (pi theme JSON)
#   - modules/home/sketchybar.nix  (colors.lua)
#
# tmux (catppuccin plugin) and ghostty (built-in "Catppuccin Mocha" theme)
# track the upstream palette on their own and are intentionally not wired here.
#
# `palette` is the name -> hex attrset; `names` preserves the canonical
# Catppuccin ordering for generated files (attrset iteration is alphabetical,
# which would scramble the conventional layout).
let
  ordered = [
    {
      name = "rosewater";
      hex = "f5e0dc";
    }
    {
      name = "flamingo";
      hex = "f2cdcd";
    }
    {
      name = "pink";
      hex = "f5c2e7";
    }
    {
      name = "mauve";
      hex = "cba6f7";
    }
    {
      name = "red";
      hex = "f38ba8";
    }
    {
      name = "maroon";
      hex = "eba0ac";
    }
    {
      name = "peach";
      hex = "fab387";
    }
    {
      name = "yellow";
      hex = "f9e2af";
    }
    {
      name = "green";
      hex = "a6e3a1";
    }
    {
      name = "teal";
      hex = "94e2d5";
    }
    {
      name = "sky";
      hex = "89dceb";
    }
    {
      name = "sapphire";
      hex = "74c7ec";
    }
    {
      name = "blue";
      hex = "89b4fa";
    }
    {
      name = "lavender";
      hex = "b4befe";
    }
    {
      name = "text";
      hex = "cdd6f4";
    }
    {
      name = "subtext1";
      hex = "bac2de";
    }
    {
      name = "subtext0";
      hex = "a6adc8";
    }
    {
      name = "overlay2";
      hex = "9399b2";
    }
    {
      name = "overlay1";
      hex = "7f849c";
    }
    {
      name = "overlay0";
      hex = "6c7086";
    }
    {
      name = "surface2";
      hex = "585b70";
    }
    {
      name = "surface1";
      hex = "45475a";
    }
    {
      name = "surface0";
      hex = "313244";
    }
    {
      name = "base";
      hex = "1e1e2e";
    }
    {
      name = "mantle";
      hex = "181825";
    }
    {
      name = "crust";
      hex = "11111b";
    }
  ];
in
{
  palette = builtins.listToAttrs (
    map (c: {
      inherit (c) name;
      value = c.hex;
    }) ordered
  );

  names = map (c: c.name) ordered;
}
