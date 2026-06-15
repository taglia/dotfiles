let
  mbp = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7IVJHXrOVQvRTdU4WFbIGLTwtsCfGym1Op4qqSZuk+G4X0/Qe6idKNPfHTJu1lqY5O8/Q7+YZ9xoJwjCZ/jDmRrd4dienTKEP31wynFWbyyiIudPE1ms8D7vvSnFQBXcF+44Bymw2iifURmL98lFcjP4rb2+l9Tv1pndMFMu5tfUox1nEkHccB3bcUSFc52rhIu2SMySLXyTSHdcihrJFsqwiYGC5MfoaG0rGOnd1jiUQzt1ipZTBvRsPlbO0wcDKMfJ85eVeszC5PI5DzrQZfS9tiaBSRaSHgxwYaSVdFmOanB9U8LgwhUSG0Gvz3UWt4SRhb+3o9mnveWCQwYiJgK+fv657KgK8HWHWz2G64mbmXB2ABNckMB5UrWLAgWHMuY/FDaZMvGZe/7auxMyNhnB5IDL57KEu6nzQTKVZUYbDJYFNEe/vA891V1XbkxsCwExcu/ZagpFEq4APiqQvKeZvZVIHibKp+AwCmfPn7PxLtID+5/7agu6WIfIqLZ8= taglia@MacBook-Pro-2.local";
  dev-vm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDqNPpIuIKtVWWtP4mHjoMhikX12+HYXk4d3K2Plcz0e taglia@dev";
in
{
  "secrets/pi-kagi-api-key.age".publicKeys = [
    mbp
    dev-vm
  ];
  "secrets/pi-ollama-api-key.age".publicKeys = [
    mbp
    dev-vm
  ];
}
