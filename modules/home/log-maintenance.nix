{ config, pkgs, ... }:

let
  maintenance = pkgs.writeShellScript "dotfiles-log-maintenance" ''
    exec ${pkgs.python3}/bin/python3 ${../../files/log-maintenance/maintain.py} \
      --home ${pkgs.lib.escapeShellArg config.home.homeDirectory}
  '';
in
{
  # These are user-owned, plain-file logs, not macOS unified logging.
  # Hourly is intentional: bounds are periodic rather than hard write limits.
  launchd.agents.log-maintenance = {
    enable = true;
    config = {
      ProgramArguments = [ "${maintenance}" ];
      StartInterval = 3600;
      ProcessType = "Background";
      LowPriorityIO = true;
      Nice = 10;
      # No file-backed stdout/stderr: the maintenance job must not create
      # another unbounded log of its own.
    };
  };
}
