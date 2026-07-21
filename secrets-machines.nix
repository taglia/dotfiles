# Machine inventory for agenix.
#
# Each entry maps a machine to:
#
#   publicKey  SSH public key used as an age recipient in secrets.nix. This is
#              what authorizes the machine to decrypt a secret.
#
#   identity   Absolute path of the matching private key on that machine. Used
#              by profiles/private.nix to build age.identityPaths; may point
#              anywhere on the filesystem (e.g. a machine-level key outside
#              the user's home), but the file must be readable by the user
#              running Home Manager activation.
#
# Adding a machine = adding one entry here. Adding a secret = one entry in
# secrets.nix (see the comment there).
{
  mbp = {
    publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7IVJHXrOVQvRTdU4WFbIGLTwtsCfGym1Op4qqSZuk+G4X0/Qe6idKNPfHTJu1lqY5O8/Q7+YZ9xoJwjCZ/jDmRrd4dienTKEP31wynFWbyyiIudPE1ms8D7vvSnFQBXcF+44Bymw2iifURmL98lFcjP4rb2+l9Tv1pndMFMu5tfUox1nEkHccB3bcUSFc52rhIu2SMySLXyTSHdcihrJFsqwiYGC5MfoaG0rGOnd1jiUQzt1ipZTBvRsPlbO0wcDKMfJ85eVeszC5PI5DzrQZfS9tiaBSRaSHgxwYaSVdFmOanB9U8LgwhUSG0Gvz3UWt4SRhb+3o9mnveWCQwYiJgK+fv657KgK8HWHWz2G64mbmXB2ABNckMB5UrWLAgWHMuY/FDaZMvGZe/7auxMyNhnB5IDL57KEu6nzQTKVZUYbDJYFNEe/vA891V1XbkxsCwExcu/ZagpFEq4APiqQvKeZvZVIHibKp+AwCmfPn7PxLtID+5/7agu6WIfIqLZ8= taglia@MacBook-Pro-2.local";
    identity = "/Users/taglia/.ssh/id_rsa";
  };
  dev-vm = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDqNPpIuIKtVWWtP4mHjoMhikX12+HYXk4d3K2Plcz0e taglia@dev";
    identity = "/home/taglia/.ssh/id_ed25519";
  };
  utm-vm = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL3MgIxGv6Acv9iPDPPjuBgnwD9Laj0uUxBl1dNHyPlI taglia@utm-vm";
    identity = "/home/taglia/.ssh/id_ed25519";
  };
  openclaw-hetzner = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIqzshme24iNdkO8oN+i1/SnVcsae9wI4LD1CTmhS05B openclaw@openclaw";
    identity = "/home/openclaw/.ssh/id_ed25519";
  };
}
