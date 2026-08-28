{ pkgs, ... }:

let
  catppuccin = import ../../lib/catppuccin.nix;
  inherit (catppuccin) palette;

  c = name: "#${palette.${name}}";

  # Claude Code custom theme, generated from the shared palette. Claude Code
  # loads ~/.claude/themes/<slug>.json and selects it via the settings.json
  # key `"theme": "custom:<slug>"`; token names come from the terminal-config
  # docs (https://code.claude.com/docs/en/terminal-config). Tokens not listed
  # in `overrides` fall back to the built-in `base` preset. The themes
  # directory is watched, so a switch restyles running sessions too.
  #
  # settings.json is deliberately not managed here: Claude Code rewrites it
  # at runtime, and the only themed key in it is the `custom:catppuccin-mocha`
  # selection.
  claudeTheme = {
    name = "catppuccin-mocha";
    base = "dark";
    overrides = {
      # Text and accents
      claude = c "mauve";
      text = c "text";
      inverseText = c "crust";
      inactive = c "overlay0";
      subtle = c "surface2";
      suggestion = c "lavender";
      permission = c "blue";
      remember = c "pink";

      # Status
      success = c "green";
      error = c "red";
      warning = c "yellow";
      merged = c "lavender";

      # Input-mode indicators
      promptBorder = c "surface1";
      planMode = c "teal";
      autoAccept = c "green";
      bashBorder = c "pink";
      ide = c "sapphire";
      fastMode = c "peach";

      # Fullscreen-mode backgrounds
      userMessageBackground = c "surface0";
      userMessageBackgroundHover = c "surface1";
      bashMessageBackgroundColor = c "mantle";
      memoryBackgroundColor = c "mantle";
      selectionBg = c "surface2";

      # Diff line backgrounds have no palette equivalent: green/red blended
      # into base at 30% (line), 50% (changed word), 15% (dimmed).
      diffAdded = "#475951";
      diffAddedWord = "#628168";
      diffAddedDimmed = "#323c3f";
      diffRemoved = "#5e3f53";
      diffRemovedWord = "#89556b";
      diffRemovedDimmed = "#3e2e40";

      # Shimmer variants: a lighter neighbour of the color they animate over.
      claudeShimmer = c "lavender";
      permissionShimmer = c "sky";
      warningShimmer = c "rosewater";
      inactiveShimmer = c "overlay2";

      # Misc chrome
      rate_limit_fill = c "mauve";
      rate_limit_empty = c "surface1";
      briefLabelYou = c "blue";
      briefLabelClaude = c "mauve";

      # Subagent identity colors
      red_FOR_SUBAGENTS_ONLY = c "red";
      orange_FOR_SUBAGENTS_ONLY = c "peach";
      yellow_FOR_SUBAGENTS_ONLY = c "yellow";
      green_FOR_SUBAGENTS_ONLY = c "green";
      cyan_FOR_SUBAGENTS_ONLY = c "teal";
      blue_FOR_SUBAGENTS_ONLY = c "blue";
      purple_FOR_SUBAGENTS_ONLY = c "mauve";
      pink_FOR_SUBAGENTS_ONLY = c "pink";
    };
  };

  # Pretty-printed via jq so the installed file stays readable.
  claudeThemeJson =
    pkgs.runCommand "claude-catppuccin-mocha.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        json = builtins.toJSON claudeTheme;
      }
      ''
        echo "$json" | jq . > $out
      '';
in
{
  home.file.".claude/themes/catppuccin-mocha.json" = {
    source = claudeThemeJson;
    force = true;
  };
}
