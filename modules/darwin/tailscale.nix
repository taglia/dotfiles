{ ... }:

{
  # Standalone tailscaled daemon, managed by nix-darwin via launchd.
  # Replaces the Tailscale Mac App Store app (previously in
  # modules/darwin/homebrew.nix masApps). The new daemon is a separate node
  # from the MAS app, so it needs a fresh `tailscale up` login after switch.
  services.tailscale = {
    enable = true;
    # Implements "Override local DNS" from the Tailscale admin panel.
    # Requires at least one DNS server + "Override local DNS" enabled in the
    # control panel, otherwise non-MagicDNS queries will fail.
    #
    # This sets `networking.dns = [ "100.100.100.100" ]`, but nix-darwin only
    # applies networking.dns via `networksetup -setdnsservers` for services
    # listed in `networking.knownNetworkServices`. Without that list the DNS
    # override is a silent no-op (only a build warning is emitted). Hence the
    # explicit list below.
    overrideLocalDns = true;
  };

  # Network services to force DNS onto during activation. Must match the
  # names from `networksetup -listallnetworkservices`. VPN services and the
  # Tailscale service itself are intentionally excluded (they manage their
  # own DNS; overriding the tunnel's DNS would be circular).
  networking.knownNetworkServices = [
    "Wi-Fi"
    "USB 10/100/1000 LAN"
    "USB 10/100/1G/2.5G LAN"
    "USB 10/100/1G/2.5G LAN 2"
    "Thunderbolt Bridge"
    "iPhone USB"
    "iPad USB"
  ];
}