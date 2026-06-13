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
    serviceConfig.ExecStart = "${pkgs.spice-vdagent}/bin/spice-vdagent -x";
  };
}
