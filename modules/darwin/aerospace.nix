{ pkgs, ... }:

# JankyBorders is started together with AeroSpace below via
# `after-startup-command`. `borders <args>` starts the daemon on first call and
# updates the already-running instance on later calls (JankyBorders
# deduplicates running instances), so this is safe across AeroSpace restarts.
# Colors: active = focused window (yellow, matches the focused-workspace pill
# in files/sketchybar/colors.lua); inactive = the other windows (gray, matches
# its `background_border`). The `borders` binary comes from `jankyborders` in
# modules/darwin/packages.nix.
let
  bordersStart = "exec-and-forget ${pkgs.jankyborders}/bin/borders style=round active_color=0xffffd166 inactive_color=0xff4b5563 width=5.0";
in
{
  # Disable macOS' native tiling/snapping so AeroSpace is the sole window
  # manager. These overlap with AeroSpace's responsibilities and would fight
  # it for control of window placement.
  system.defaults.WindowManager = {
    EnableTiledWindowMargins = false;
    EnableTilingByEdgeDrag = false;
    EnableTopTilingByEdgeDrag = false;
    GloballyEnabled = false;
    EnableStandardClickToShowDesktop = false;
  };

  services.aerospace = {
    enable = true;
    package = pkgs.aerospace;

    settings = {
      after-login-command = [ ];
      after-startup-command = [ bordersStart ];

      # Notify SketchyBar on AeroSpace workspace change so the workspace
      # indicator (files/sketchybar/items/spaces.lua) can highlight the
      # focused workspace. We don't use macOS Spaces, so AeroSpace workspaces
      # are the only notion of "workspace".
      exec-on-workspace-change = [
        "/bin/bash"
        "-c"
        "${pkgs.sketchybar}/bin/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
      ];

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 120;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      key-mapping.preset = "qwerty";

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      automatically-unhide-macos-hidden-apps = false;

      gaps = {
        inner = {
          horizontal = 10;
          vertical = 10;
        };
        outer = {
          left = 10;
          bottom = 10;
          # Reserve space at the top for SketchyBar (height=38) so tiled
          # windows sit below it with a ~10px gap instead of sliding under it.
          # macOS gives third-party bars no "reserve screen space" API, so the
          # WM must leave the gap: external displays get 38 (bar) + 10 (gap) =
          # 48. The built-in MacBook display already loses its top area to the
          # notch/menu-bar zone (which covers the bar), so it only needs a small
          # gap there. Per-monitor gaps are an AeroSpace array of overrides;
          # the last bare value is the default for any monitor not matched.
          top = [
            { monitor."built-in" = 10; }
            48
          ];
          right = 10;
        };
      };

      mode = {
        main.binding = {
          cmd-h = [ ];
          cmd-alt-h = [ ];

          alt-slash = "layout tiles horizontal vertical";
          alt-comma = "layout accordion horizontal vertical";

          alt-h = [
            "focus left"
            "move-mouse window-lazy-center"
          ];
          alt-j = [
            "focus down"
            "move-mouse window-lazy-center"
          ];
          alt-k = [
            "focus up"
            "move-mouse window-lazy-center"
          ];
          alt-l = [
            "focus right"
            "move-mouse window-lazy-center"
          ];

          alt-f = "fullscreen";
          alt-shift-f = "layout floating tiling";

          alt-shift-h = "move left";
          alt-shift-j = "move down";
          alt-shift-k = "move up";
          alt-shift-l = "move right";

          alt-shift-minus = "resize smart -50";
          alt-shift-equal = "resize smart +50";

          alt-1 = "workspace 1";
          alt-2 = "workspace 2";
          alt-3 = "workspace 3";
          alt-4 = "workspace 4";
          alt-5 = "workspace 5";
          alt-6 = "workspace 6";
          alt-7 = "workspace 7";
          alt-8 = "workspace 8";
          alt-9 = "workspace 9";

          alt-shift-1 = "move-node-to-workspace 1";
          alt-shift-2 = "move-node-to-workspace 2";
          alt-shift-3 = "move-node-to-workspace 3";
          alt-shift-4 = "move-node-to-workspace 4";
          alt-shift-5 = "move-node-to-workspace 5";
          alt-shift-6 = "move-node-to-workspace 6";
          alt-shift-7 = "move-node-to-workspace 7";
          alt-shift-8 = "move-node-to-workspace 8";
          alt-shift-9 = "move-node-to-workspace 9";

          alt-tab = "workspace-back-and-forth";
          alt-shift-tab = "move-workspace-to-monitor --wrap-around next";

          alt-shift-semicolon = "mode service";
        };

        service.binding = {
          esc = [
            "reload-config"
            "mode main"
          ];
          r = [
            "flatten-workspace-tree"
            "mode main"
          ];
          f = [
            "layout floating tiling"
            "mode main"
          ];
          backspace = [
            "close-all-windows-but-current"
            "mode main"
          ];

          alt-shift-h = [
            "join-with left"
            "mode main"
          ];
          alt-shift-j = [
            "join-with down"
            "mode main"
          ];
          alt-shift-k = [
            "join-with up"
            "mode main"
          ];
          alt-shift-l = [
            "join-with right"
            "mode main"
          ];
        };
      };

      workspace-to-monitor-force-assignment = {
        "1" = "secondary";
        "9" = "secondary";
      };

      # NOTE: order matters. AeroSpace walks on-window-detected callbacks in list
      # order and stops at the first match unless `check-further-callbacks = true`
      # (switch/break semantics). Matchers are re-evaluated live per callback, and
      # every `run` command is pinned to the detected window via $AEROSPACE_WINDOW_ID,
      # so a `move-node-to-workspace` here is seen by later matchers and `layout`
      # targets the detected window's (possibly new) parent container.
      #
      # Keep the workspace `layout accordion` rules LAST: a window that matches one
      # of them and has `check-further-callbacks = false` (the default) stops the
      # chain, so anything that must also run (app moves, floating rules) has to
      # come first. Move rules set `check-further-callbacks = true` so they keep
      # walking to the workspace rules, which then accordion the DESTINATION
      # workspace (e.g. Mail -> ws 2 -> ws 2 becomes accordion) without stealing
      # focus (no --focus-follows-window needed).
      on-window-detected = [
        {
          "if".app-id = "com.apple.mail";
          check-further-callbacks = true;
          run = "move-node-to-workspace 2";
        }
        {
          "if".app-id = "com.omnigroup.OmniFocus4";
          check-further-callbacks = true;
          run = "move-node-to-workspace 2";
        }
        {
          "if".app-id = "com.flexibits.fantastical2.mac";
          check-further-callbacks = true;
          run = "move-node-to-workspace 2";
        }
        {
          "if".app-id = "org.ferdium.ferdium-app";
          check-further-callbacks = true;
          run = "move-node-to-workspace 4";
        }
        {
          "if".app-name-regex-substring = "Messages";
          run = "layout floating";
        }
        {
          "if".app-id = "com.agiletortoise.Drafts-OSX";
          run = "layout floating";
        }
        {
          "if".app-name-regex-substring = "Signal";
          run = "layout floating";
        }
        {
          "if".app-name-regex-substring = "Threema";
          run = "layout floating";
        }
        {
          "if".app-name-regex-substring = "iPhone Mirroring";
          run = "layout floating";
        }
        {
          "if".app-id = "com.apple.ActivityMonitor";
          run = "layout floating";
        }
        {
          "if".app-id = "com.mitchellh.ghostty";
          check-further-callbacks = true;
          run = "move-node-to-workspace 5";
        }
        {
          "if".app-id = "com.appliedphasor.secure-shellfish";
          check-further-callbacks = true;
          run = "move-node-to-workspace 5";
        }
        {
          "if".app-id = "com.kk2.rootshell";
          check-further-callbacks = true;
          run = "move-node-to-workspace 5";
        }
        {
          "if".app-id = "com.1password.1password";
          run = "layout floating";
        }
        {
          "if".app-id = "com.protonmail.bridge";
          run = "layout floating";
        }
        {
          "if".workspace = "1";
          run = "layout accordion";
        }
        {
          "if".workspace = "2";
          run = "layout accordion";
        }
      ];
    };
  };
}