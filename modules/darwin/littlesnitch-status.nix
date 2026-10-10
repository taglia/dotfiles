{
  lib,
  pkgs,
  user,
  ...
}:

let
  publisher = pkgs.writeShellScript "littlesnitch-status" ''
    set -eu
    uid=$(/usr/bin/id -u ${lib.escapeShellArg user.username})
    # Adopt the desktop user's bootstrap/audit session, retaining root UID.
    # --user selects preferences but does not establish that session itself.
    exec /bin/launchctl asuser "$uid" \
      ${pkgs.python3}/bin/python3 ${../../files/littlesnitch-status/publish.py} \
      --user ${lib.escapeShellArg user.username}
  '';
in
{
  # Root reads fixed preferences for the desktop user; SketchyBar only reads
  # /var/run/dotfiles-littlesnitch/status.json. No sudo grant or writable helper.
  # Little Snitch's "Allow access via Terminal" must be enabled separately.
  launchd.daemons.littlesnitch-status.serviceConfig = {
    # Launchd may start this before the Nix volume is mounted. The first
    # executable must live on the system volume, not in /nix/store.
    ProgramArguments = [
      "/bin/sh"
      "-c"
      "/bin/wait4path /nix/store && exec ${publisher}"
    ];
    UserName = "root";
    RunAtLoad = true;
    StartInterval = 15;
    # Background scheduling can stall the CLI's preference reads indefinitely.
    # Standard/default still throttles CPU and I/O; Interactive removes those
    # limits so the probe runs like the successful foreground CLI invocation.
    ProcessType = "Interactive";
    # No KeepAlive: this is a bounded one-shot probe, retried on the interval.
  };
}
