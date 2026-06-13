{ pkgs, ... }:

{
  # QEMU/UTM guest integration: SPICE clipboard sharing, dynamic resolution,
  # seamless mouse, and the guest agent. Reusable for any QEMU-based VM; leave
  # it out on physical machines.
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  # The session-side SPICE agent does not autostart reliably under GNOME, so run
  # it as a user service bound to the graphical session. Without it the daemon
  # has nothing to talk to and clipboard/mouse/resize stay broken.
  systemd.user.services.spice-vdagent = {
    description = "spice-vdagent session agent";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
      # The session's DISPLAY/WAYLAND_DISPLAY may not be in the user manager's
      # environment the instant the target is reached ("could not connect to
      # X-server"); retry until the display is ready.
      Restart = "on-failure";
      RestartSec = 2;
    };
    # Don't let those retries trip systemd's start-rate limit.
    unitConfig.StartLimitIntervalSec = 0;
  };
}
