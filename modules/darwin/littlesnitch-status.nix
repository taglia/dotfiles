{ pkgs, user, ... }:

{
  # Root reads fixed preferences for the desktop user; SketchyBar only reads
  # /var/run/dotfiles-littlesnitch/status.json. No sudo grant or writable helper.
  # Little Snitch's "Allow access via Terminal" must be enabled separately.
  launchd.daemons.littlesnitch-status.serviceConfig = {
    ProgramArguments = [
      "${pkgs.python3}/bin/python3"
      "${../../files/littlesnitch-status/publish.py}"
      "--user"
      user.username
    ];
    UserName = "root";
    RunAtLoad = true;
    StartInterval = 15;
    ProcessType = "Background";
    LowPriorityIO = true;
    # No KeepAlive: this is a bounded one-shot probe, retried on the interval.
  };
}
