{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

# JankyBorders is started together with AeroSpace below via
# `after-startup-command`. `borders <args>` starts the daemon on first call and
# updates the already-running instance on later calls (JankyBorders
# deduplicates running instances), so this is safe across AeroSpace restarts.
# Colors: active = focused window (yellow, matches the focused-workspace pill
# in files/sketchybar/colors.lua); inactive = the other windows (gray, matches
# its `background_border`). The `borders` binary comes from `jankyborders` in
# modules/darwin/packages.nix. `blacklist` excludes apps whose process name
# matches (case-sensitive) — iPhone Mirroring draws its own rounded frame, so
# a border on top looks wrong.
let
  # Keep the app, SketchyBar's CLI dependency, and workspace-change trigger
  # on the same pinned unstable packages (see modules/home/sketchybar.nix).
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  inherit (import ../../lib/catppuccin.nix) palette;
  bordersStart = "exec-and-forget ${pkgs.jankyborders}/bin/borders style=round active_color=0xff${palette.yellow} inactive_color=0xff${palette.crust} width=5.0 blacklist=\"iPhone Mirroring\"";

  # Apps opened when AeroSpace starts, i.e. at login, so their windows exist
  # once the on-window-detected rules below are active. Names as the bundle
  # appears in /Applications, without ".app". Every extra app slows login
  # down, so keep this to the apps that are wanted every day.
  # `open -g` does not bring the app to the foreground and is a no-op when it
  # is already running, so an AeroSpace restart (e.g. after darwin-rebuild
  # switch) neither relaunches the apps nor steals focus. after-login-command
  # would be the natural home, but it is deprecated since AeroSpace 0.19
  # (https://github.com/nikitabobko/AeroSpace/issues/1482) and never fires
  # under nix-darwin's launchd agent anyway.
  startupApps = [
    "Obsidian"
    "Ghostty"
    "Orion"
    "Mail"
    "Fantastical"
    "OmniFocus"
    "Ferdium"
  ];
  openAtStartup = map (app: "exec-and-forget open -g -a '${app}'") startupApps;

  # SketchyBar event trigger for AeroSpace callbacks and bindings. Absolute
  # store path: callbacks run with AeroSpace's exec PATH, which has the Nix
  # profiles only since exec.env-vars below, and the bar's own package is the
  # one to notify anyway.
  sketchybarTrigger =
    event: "exec-and-forget ${unstable.sketchybar}/bin/sketchybar --trigger ${event}";

  # Toggle floating for the focused window and tell the bar: toggling does not
  # change focus, so on-focus-changed alone would miss it (items/floating.lua).
  toggleFloating = [
    "layout floating tiling"
    (sketchybarTrigger "aerospace_focus_change")
  ];

  # The workspaces bound to alt-N below. Also declared persistent, so an
  # empty one keeps existing (and keeps its SketchyBar slot) instead of being
  # garbage-collected.
  workspaces = map toString (lib.range 1 9);

  # alt-N focuses workspace N; pressing it again on that workspace bounces
  # back to the previous one (--auto-back-and-forth). alt-shift-N moves the
  # focused window there without following it.
  workspaceBindings = lib.listToAttrs (
    lib.concatMap (ws: [
      (lib.nameValuePair "alt-${ws}" "workspace --auto-back-and-forth ${ws}")
      (lib.nameValuePair "alt-shift-${ws}" "move-node-to-workspace ${ws}")
    ]) workspaces
  );

  # Directional focus wraps at the workspace edge instead of stopping, and
  # the pointer follows the newly focused window.
  focusBinding = dir: [
    "focus --boundaries-action wrap-around-the-workspace ${dir}"
    "move-mouse window-lazy-center"
  ];
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

  # Mission Control previews one group per app rather than one per window;
  # with a workspace full of tiles the per-window thumbnails are too small to
  # tell apart (recommended in the AeroSpace guide).
  system.defaults.dock.expose-group-apps = true;

  # Move a window by ctrl-cmd-dragging anywhere inside it, not only on its
  # title bar (AeroSpace goodies). Had been set by hand on the mbp; declared
  # here so it survives a reinstall.
  system.defaults.NSGlobalDomain.NSWindowShouldDragOnGesture = true;

  services.aerospace = {
    enable = true;
    package = unstable.aerospace;

    settings = {
      # Version 2 makes persistent-workspaces explicit; version 1 inferred it
      # from the keybindings and reload-config warns about it since 0.21.
      config-version = 2;
      persistent-workspaces = workspaces;

      after-startup-command = [ bordersStart ] ++ openAtStartup;

      # PATH for exec-and-forget bindings and callbacks. AeroSpace's own
      # fallback is Homebrew + system paths only, so Nix-installed tools had
      # to be called by store path; the Nix profiles come first here.
      # ${PATH} is expanded by AeroSpace, not Nix.
      exec.env-vars.PATH = lib.concatStringsSep ":" [
        "/etc/profiles/per-user/${config.system.primaryUser}/bin"
        "/run/current-system/sw/bin"
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
        "\${PATH}"
      ];

      # Notify SketchyBar on AeroSpace workspace change so the workspace
      # indicator (files/sketchybar/items/spaces.lua) can highlight the
      # focused workspace. We don't use macOS Spaces, so AeroSpace workspaces
      # are the only notion of "workspace".
      exec-on-workspace-change = [
        "/bin/bash"
        "-c"
        "${unstable.sketchybar}/bin/sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
      ];

      # Notify SketchyBar on binding-mode change so items/mode.lua can show the
      # service mode. The callback receives no variable with the new mode;
      # mode.lua re-queries `aerospace list-modes --current`.
      on-mode-changed = [ (sketchybarTrigger "aerospace_mode_change") ];

      # Notify SketchyBar on focus change so items/floating.lua can flag a
      # floating focused window. Fires on window and workspace changes; the
      # floating toggles below fire it explicitly.
      on-focus-changed = [ (sketchybarTrigger "aerospace_focus_change") ];

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 120;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      key-mapping.preset = "qwerty";

      # Disabled: AeroSpace's hover focusing steals focus from transient
      # popups (FineTune, Rhino selectors). Keep keyboard-driven mouse warping.
      focus-follows-mouse.enabled = false;
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
          # The non-auto-hidden native menu bar already reserves 31 points
          # on the current external display. Add only 38 (SketchyBar height)
          # + 10 (desired spacing) - 31 = 17, avoiding a double reservation.
          # Recheck if display scaling or native menu-bar geometry changes.
          # The built-in notch/menu-bar zone covers SketchyBar already.
          # The last bare value is the default for unmatched monitors.
          top = [
            { monitor."built-in" = 10; }
            17
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

          alt-h = focusBinding "left";
          alt-j = focusBinding "down";
          alt-k = focusBinding "up";
          alt-l = focusBinding "right";

          alt-f = "fullscreen";
          alt-shift-f = toggleFloating;

          alt-shift-h = "move left";
          alt-shift-j = "move down";
          alt-shift-k = "move up";
          alt-shift-l = "move right";

          # Swap exchanges the focused window with its neighbour and leaves
          # the tree alone; `move` (alt-shift) restructures it instead.
          alt-ctrl-h = "swap left";
          alt-ctrl-j = "swap down";
          alt-ctrl-k = "swap up";
          alt-ctrl-l = "swap right";

          alt-shift-minus = "resize smart -50";
          alt-shift-equal = "resize smart +50";

          alt-tab = "workspace-back-and-forth";
          # No effect on workspaces 1 and 9: move-workspace-to-monitor refuses
          # force-assigned workspaces (see below).
          alt-shift-tab = "move-workspace-to-monitor --wrap-around next";

          alt-shift-semicolon = "mode service";
        }
        // workspaceBindings;

        service.binding = {
          esc = [
            "reload-config"
            "mode main"
          ];
          r = [
            "flatten-workspace-tree"
            "mode main"
          ];
          f = toggleFloating ++ [ "mode main" ];
          backspace = [
            "close-all-windows-but-current"
            "mode main"
          ];
          # Even out the window sizes on the workspace after a few resizes.
          b = [
            "balance-sizes"
            "mode main"
          ];
          # Suspend tiling (screen sharing, games). While disabled AeroSpace
          # intercepts no keys at all, so this only ever turns it off. The
          # way back is the red "TILING OFF" pill SketchyBar shows meanwhile
          # (files/sketchybar/items/mode.lua): clicking it runs `aerospace
          # enable on`, which also restores the main binding mode. The menu
          # bar icon and the CLI work too.
          t = "enable toggle";

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
        # Orion
        {
          "if".app-id = "com.kagi.kagimacOS";
          check-further-callbacks = true;
          run = "move-node-to-workspace 1";
        }
        {
          "if".app-id = "com.devon-technologies.think";
          check-further-callbacks = true;
          run = "move-node-to-workspace 1";
        }
        {
          "if".app-id = "md.obsidian";
          check-further-callbacks = true;
          run = "move-node-to-workspace 1";
        }
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
          "if".app-id = "com.bambulab.bambu-studio";
          check-further-callbacks = true;
          run = "move-node-to-workspace 6";
        }
        # Rhino 8 and the Rhino 9 beta are separate bundles.
        {
          "if".app-id = "com.mcneel.rhinoceros.8";
          check-further-callbacks = true;
          run = "move-node-to-workspace 6";
        }
        {
          "if".app-id = "com.mcneel.rhinoceros.9";
          check-further-callbacks = true;
          run = "move-node-to-workspace 6";
        }
        {
          "if".app-id = "com.apple.Music";
          check-further-callbacks = true;
          run = "move-node-to-workspace 7";
        }
        {
          "if".app-id = "com.apple.MobileSMS"; # Messages
          run = "layout floating";
        }
        {
          "if".app-id = "com.agiletortoise.Drafts-OSX";
          run = "layout floating";
        }
        {
          "if".app-id = "org.whispersystems.signal-desktop";
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
        {
          "if".workspace = "6";
          run = "layout accordion";
        }
      ];
    };
  };
}
