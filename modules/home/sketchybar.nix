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
# the config dir to LUA_PATH only in the source path).
#
# `configType = "lua"` drives the wrapper: it pulls in pkgs.sbarlua, auto-infers
# the Lua interpreter from sbarlua.passthru.luaModule, and adds sbarlua to
# LUA_PATH/LUA_CPATH so `require("sketchybar")` resolves. The `sbar` global is
# NOT auto-loaded, so the entry file begins with `sbar = require("sketchybar")`.
# The entry file (files/sketchybar/sketchybarrc, no extension — sketchybar looks
# for that exact name) is executable and carries its own shebang, since the
# directory-source copy is verbatim.
#
# `extraPackages` puts `aerospace` on the wrapper's PATH so the workspace
# indicator (items/spaces.lua) can run `aerospace workspace N` (click_script)
# and `aerospace list-workspaces --focused` without an absolute path.
{ pkgs, ... }:

let
  sketchybarConfigDir = ../../files/sketchybar;
in
{
  programs.sketchybar = {
    enable = true;
    configType = "lua";
    config = {
      source = sketchybarConfigDir;
      recursive = true;
    };
    extraPackages = [ pkgs.aerospace ];
  };
}
