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
# The Lua config itself lives in files/sketchybar/sketchybarrc.lua and is pulled
# in via `config.source`, keeping this module short and matching the convention
# used elsewhere (e.g. the mouseless config path in darwin-apps.nix). The HM
# module installs the file at ~/.config/sketchybar/sketchybarrc (the destination
# name is fixed by the module, so the source can carry a .lua extension for
# editor/syntax-highlighting); the copy is verbatim, so the source file carries
# its own `#!/usr/bin/env lua` shebang and is executable.
#
# `configType = "lua"` still drives the wrapper: it pulls in pkgs.sbarlua, auto-
# infers the Lua interpreter from sbarlua.passthru.luaModule, and adds sbarlua
# to LUA_PATH/LUA_CPATH so `require("sketchybar")` resolves. The `sbar` global
# is NOT auto-loaded, so the config file begins with `sbar = require("sketchybar")`.
#
# To grow into a plugin-style multi-file config later, switch to a directory
# source: config = { source = ../../files/sketchybar; recursive = true; }; with
# the entry file named `sketchybarrc` (NO extension — sketchybar looks for that
# exact name) inside that directory. The HM wrapper adds the config dir to
# LUA_PATH only in the source path, so require() of siblings then resolves.
{ ... }:

let
  sketchybarConfig = ../../files/sketchybar/sketchybarrc.lua;
in
{
  programs.sketchybar = {
    enable = true;
    configType = "lua";
    config.source = sketchybarConfig;
  };
}