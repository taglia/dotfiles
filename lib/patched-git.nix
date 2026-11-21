# SECURITY FIX (2026-11-21): Git 2.54.1 for the `git` on PATH.
#
# Git's 2026-11-10 security release fixes six CVEs, the worst being
# CVE-2026-111760 (code execution during `git clone --recurse-submodules` of a
# malicious repository). nixos-26.05 still ships 2.54.0: the bump
# (NixOS/nixpkgs#586429) is merged into `staging-26.05` only, and
# nixos-unstable's 2.56.0 is affected as well, so there is no channel to pin
# to. This mirrors that PR (same version and source hash) and is built
# locally, once per machine.
#
# Use it only where Git is installed for people and agents to run
# (`programs.git.package`, `environment.systemPackages`). Do not turn it into
# an overlay: everything that fetches with Git would rebuild.
#
# `doInstallCheck = false` skips Git's test suite, which nixpkgs already skips
# on Darwin and which would add a long run to every Linux host.
#
# Self-disabling: once the channel's own Git is >= 2.54.1 this returns
# `pkgs.git` unchanged. Remove the file and its callers then (see AGENTS.md,
# "Pending upstream checks").
pkgs:
let
  version = "2.54.1";
in
if pkgs.lib.versionOlder pkgs.git.version version then
  (pkgs.git.override { doInstallCheck = false; }).overrideAttrs {
    inherit version;
    src = pkgs.fetchurl {
      url = "https://www.kernel.org/pub/software/scm/git/git-${version}.tar.xz";
      hash = "sha256-ypiOua99h3AznffNw4EG/sgkRmT/iGhAdny5vj7w4Ww=";
    };
  }
else
  pkgs.git
