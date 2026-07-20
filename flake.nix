{
  description = "Nix configuration for my machines: Home Manager, nix-darwin and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.darwin.follows = "nix-darwin";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      ...
    }:
    let
      # Local identity. The attrset below is the upstream default; forks and
      # other machines override it with an optional, git-ignored
      # identity.nix (written by scripts/bootstrap_and_switch.sh). flake.nix
      # imports it when present, so the tracked flake.nix stays untouched
      # across machines. Delete identity.nix to fall back to the defaults.
      # Note: Nix only sees files git knows about, so identity.nix must be
      # marked with `git add -N -f` (the bootstrap script does this); a plain
      # untracked file would be silently ignored here.
      defaultUser =
        if builtins.pathExists ./identity.nix then
          import ./identity.nix
        else
          {
            username = "taglia";
            githubUsername = "taglia";
            email = "612306+taglia@users.noreply.github.com";
          };

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Everything a Home Manager / nix-darwin / NixOS module might need from
      # the flake. `inputs` carries the full bundle (agenix, nixpkgs-unstable,
      # ...), so modules reference e.g. `inputs.agenix` / `inputs.nixpkgs-unstable`
      # rather than receiving them as separate args.
      homeSpecialArgs = {
        inherit inputs;
        user = defaultUser;
      };

      hostLib = import ./lib/hosts.nix {
        inherit
          nixpkgs
          homeSpecialArgs
          defaultUser
          ;
        inherit (inputs)
          home-manager
          nix-darwin
          nixvim
          agenix
          nix-index-database
          ;
      };

      inherit (hostLib)
        hosts
        darwinHosts
        nixosHosts
        ;

      # `mbp-home` is an alias of the standalone Home Manager configuration for
      # `mbp`, kept for the README's documented name. Defined separately so the
      # checks below (derived from `hosts`) don't build the same derivation twice.
      homeConfigurations = hostLib.homeConfigurations // {
        mbp-home = hostLib.homeConfigurations.mbp;
      };
    in
    {
      inherit homeConfigurations;
      inherit (hostLib) darwinConfigurations nixosConfigurations;

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "nixfmt-dotfiles";
          runtimeInputs = [ pkgs.nixfmt ];
          text = ''
            # `nix fmt -- --check` runs `nixfmt --check`; plain `nix fmt`
            # formats in place. With explicit file/dir arguments nixfmt
            # formats those paths instead of the whole repo.
            check=""
            if [ "''${1:-}" = "--check" ]; then
              check="--check"
              shift
            fi

            if [ "$#" -gt 0 ]; then
              exec nixfmt $check "$@"
            fi

            find . -path ./.git -prune -o -name '*.nix' -type f -print0 | xargs -0 nixfmt $check
          '';
        }
      );

      checks = forAllSystems (
        system:
        let
          homeChecks = nixpkgs.lib.mapAttrs' (
            name: _:
            nixpkgs.lib.nameValuePair "home-${name}" hostLib.homeConfigurations.${name}.activationPackage
          ) (nixpkgs.lib.filterAttrs (_: host: host.system == system) hosts);

          darwinChecks = nixpkgs.lib.listToAttrs (
            map (name: {
              name = "darwin-${name}";
              value = hostLib.darwinConfigurations.${name}.system;
            }) (builtins.filter (name: darwinHosts.${name}.system == system) (builtins.attrNames darwinHosts))
          );

          nixosChecks = nixpkgs.lib.listToAttrs (
            map (name: {
              name = "nixos-${name}";
              value = hostLib.nixosConfigurations.${name}.config.system.build.toplevel;
            }) (builtins.filter (name: nixosHosts.${name}.system == system) (builtins.attrNames nixosHosts))
          );
        in
        homeChecks // darwinChecks // nixosChecks
      );
    };
}
