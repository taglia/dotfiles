# SketchyBar status bar, managed by Home Manager.
#
# Lives in the Home Manager layer (not nix-darwin) on purpose: SketchyBar is a
# per-user program with per-user config in ~/.config/sketchybar and runs as a
# *user launchd agent, and Home Manager ships a first-class `programs.sketchybar`
# module that handles the package, the SBarLua/Lua wrapper, the config file, and
# the LaunchAgent for us. nix-darwin has no equivalent module. This mirrors the
# split already in this repo: AeroSpace (system-level WM) is configured under
# modules/darwin/aerospace.nix via nix-darwin, while SketchyBar (user-level
# status bar) lives here under modules/home.
#
# Imported only for the `mbp` darwin host (see flake.nix hosts.mbp.modules), so
# it never reaches the Linux homeConfigurations. The HM module also asserts a
# Darwin platform as a backstop.
#
# The SketchyBar config itself is kept as a self-contained, separately-identified
# tree under files/sketchybar/ (see files/sketchybar/README.md for its origin,
# the nix-adaptations applied, and its external dependencies). It is pulled in
# here as a *directory* source so the whole multi-file Lua config (sketchybarrc
# entry + init.lua + items/ + helpers/) is installed verbatim into
# ~/.config/sketchybar/ and require() of siblings resolves (the HM wrapper adds
# the config dir to LUA_PATH only in the source path). One file is injected at
# build time: colors.lua is generated from lib/catppuccin.nix, the repo's
# single source of truth for the Catppuccin palette, so it is deliberately
# absent from files/sketchybar/.
#
# `configType = "lua"` drives the wrapper: it pulls in pkgs.sbarlua, auto-infers
# the Lua interpreter from sbarlua.passthru.luaModule, and adds sbarlua to
# LUA_PATH/LUA_CPATH so `require("sketchybar")` resolves. The `sbar` global is
# NOT auto-loaded, so the entry file begins with `sbar = require("sketchybar")`.
# The entry file (files/sketchybar/sketchybarrc, no extension — sketchybar looks
# for that exact name) is executable and carries its own shebang, since the
# directory-source copy is verbatim.
#
# `extraPackages` puts tools on the wrapper's PATH: `aerospace` so the
# workspace indicator (items/spaces.lua) can run `aerospace workspace N`
# (click_script) and `aerospace list-workspaces --focused` without an absolute
# path, and `m1ddc` so the volume item (items/volume.lua) can drive the
# external monitor's hardware volume/mute over DDC/CI when the default output
# is an HDMI/DisplayPort display (which macOS exposes no software volume for).
{ lib, pkgs, ... }:

let
  catppuccin = import ../../lib/catppuccin.nix;
  inherit (catppuccin) palette;

  sketchybarConfigDir = ../../files/sketchybar;

  # colors.lua, generated from the shared palette. SketchyBar colors are
  # 0xAARRGGBB (alpha in the high byte); every palette color is fully opaque.
  colorsLua = pkgs.writeText "colors.lua" ''
    -- GENERATED from lib/catppuccin.nix by modules/home/sketchybar.nix —
    -- do not edit by hand. Values are 0xAARRGGBB (alpha in the high byte).
    --
    -- The translucent "liquid glass" colors looked reasonable in hex but
    -- rendered as dark gray on darker gray on this MBP. This palette
    -- intentionally favors readability over subtlety: opaque near-black bar,
    -- pure-white text, and a bright yellow focused-workspace pill with black
    -- text.
    local colors = {}

    -- Common
    colors.white = 0xffffffff
    colors.black = 0xff000000
    colors.transparent = 0x00000000

    -- Catppuccin Mocha (https://catppuccin.com/palette/)
    -- Prefixed with mocha_ to avoid colliding with the common colors above
    -- (red, yellow, white, black).
    ${lib.concatStringsSep "\n" (
      map (name: "colors.mocha_${name} = 0xff${palette.${name}}") catppuccin.names
    )}

    return colors
  '';

  # The config tree with the generated colors.lua injected (see the header
  # comment). Plain `cp -rL` preserves the executable bits that matter
  # (sketchybar *executes* sketchybarrc — it must stay 755); only the top
  # directory is made writable so colors.lua can be injected into it.
  sketchybarConfig = pkgs.runCommand "sketchybar-config" { } ''
    cp -rL ${sketchybarConfigDir} $out
    chmod u+w $out
    cp ${colorsLua} $out/colors.lua
  '';
in
{
  programs.sketchybar = {
    enable = true;
    configType = "lua";
    config = {
      source = sketchybarConfig;
      recursive = true;
    };
    extraPackages = [
      pkgs.aerospace
      pkgs.m1ddc
    ];
  };
}
