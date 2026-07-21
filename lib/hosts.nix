# Host table and the builders that turn each entry into a Home Manager,
# nix-darwin or NixOS configuration. Kept out of flake.nix so the flake outputs
# stay thin; flake.nix wires inputs in and re-exports the results.
#
# `defaultUser` and `homeSpecialArgs` are passed in from flake.nix (the flake
# owns identity, via the optional git-ignored identity.nix, and the inputs
# bundle). All relative paths here are relative to this file (lib/), so they
# point at ../profiles, ../modules and ../hosts.
{
  nixpkgs,
  home-manager,
  nix-darwin,
  nixvim,
  agenix,
  nix-index-database,
  homeSpecialArgs,
  defaultUser,
}:

let
  inherit (nixpkgs) lib;

  mkHomeModules =
    {
      system,
      modules ? [ ],
      user ? defaultUser,
    }:
    let
      isDarwin = lib.hasSuffix "-darwin" system;
      platformModule = if isDarwin then ../profiles/darwin.nix else ../profiles/linux.nix;
      inherit (user) username;
    in
    [
      nixvim.homeModules.nixvim
      agenix.homeManagerModules.default
      nix-index-database.homeModules.nix-index

      {
        home.username = username;

        home.homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";

        home.stateVersion = "25.11";
      }

      ../profiles/base.nix
      platformModule
    ]
    ++ modules;

  mkHome =
    {
      system,
      modules ? [ ],
      user ? defaultUser,
    }:
    let
      pkgs = import nixpkgs { inherit system; };
    in
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      extraSpecialArgs = homeSpecialArgs // {
        inherit user;
      };

      modules = mkHomeModules { inherit system modules user; };
    };

  mkDarwin =
    {
      system,
      modules ? [ ],
      user ? defaultUser,
    }:
    nix-darwin.lib.darwinSystem {
      inherit system;

      specialArgs = homeSpecialArgs // {
        inherit user;
      };

      modules = [
        home-manager.darwinModules.home-manager
        ../modules/darwin/aerospace.nix
        ../modules/darwin/core.nix
        ../modules/darwin/desktop.nix
        ../modules/darwin/homebrew.nix
        ../modules/darwin/input.nix
        ../modules/darwin/packages.nix
        ../modules/darwin/system.nix

        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = homeSpecialArgs // {
              inherit user;
            };
            users.${user.username}.imports = mkHomeModules { inherit system modules user; };
          };
        }
      ];
    };

  mkNixos =
    {
      system,
      hostModule,
      homeModules ? fullModules,
      user ? defaultUser,
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = homeSpecialArgs // {
        inherit user;
      };

      modules = [
        hostModule

        # Integrate Home Manager into the system, same as on darwin, so the
        # user environment from this repo (fish, nvim, tmux, ...) comes along.
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = homeSpecialArgs // {
              inherit user;
            };
            users.${user.username}.imports = mkHomeModules {
              inherit system user;
              modules = homeModules;
            };
          };
        }
      ];
    };

  fullModules = [
    ../modules/home/dev.nix
    ../modules/home/packages-dev.nix
    ../modules/home/media.nix
  ];

  # The Home Manager module set shared by the standalone `linux-private`
  # configuration and the `utm-vm` NixOS host, so the VM gets the same user
  # environment (AI tools + private agenix secrets) as `linux-private`, just
  # built for aarch64-linux instead of x86_64-linux. Architecture is handled
  # by mkNixos importing nixpkgs with the host's `system`, so nothing extra
  # is needed here for ARM.
  privateModules = fullModules ++ [
    ../profiles/ai.nix
    ../profiles/private.nix
  ];

  hosts = rec {
    linux = {
      system = "x86_64-linux";
      modules = fullModules;
    };

    linux-ai = {
      system = "x86_64-linux";
      modules = fullModules ++ [ ../profiles/ai.nix ];
    };

    linux-private = {
      system = "x86_64-linux";
      modules = privateModules;
    };

    # Minimal profiles: base profile only (no modules). Spelled out as
    # explicit attrsets (like the other hosts) rather than relying on
    # `host.modules or [ ]` at the call site.
    linux-minimal = {
      system = "x86_64-linux";
      modules = [ ];
    };

    linux-aws = {
      system = "x86_64-linux";
      user = defaultUser // {
        username = "admin";
      };
      modules = fullModules ++ [ ../profiles/ai.nix ];
    };

    linux-openclaw = {
      system = "x86_64-linux";
      user = defaultUser // {
        username = "openclaw";
      };
      modules = fullModules ++ [ ../profiles/private.nix ];
    };

    linux-arm = {
      system = "aarch64-linux";
      modules = fullModules;
    };

    linux-minimal-arm = {
      system = "aarch64-linux";
      modules = [ ];
    };

    mbp = {
      system = "aarch64-darwin";
      modules = fullModules ++ [
        ../profiles/ai.nix
        ../profiles/private.nix
        # Games and terminal toys (cmatrix, asciiquarium, nethack) plus
        # chess-tui wired to gnuchess --uci as its bot engine. Kept on the
        # mbp profile only, so the other hosts stay lean.
        ../modules/home/entertainment.nix
        # Darwin-only: SketchyBar runs as a user launchd agent and its HM
        # module asserts a Darwin platform, so keep it out of the Linux
        # homeConfigurations by importing it here rather than in
        # profiles/base.nix or profiles/darwin.nix.
        ../modules/home/sketchybar.nix
      ];
    };
  };

  darwinHosts = {
    inherit (hosts) mbp;
  };

  nixosHosts = {
    utm-vm = {
      system = "aarch64-linux";
      hostModule = ../hosts/utm-vm;
      # Match the `linux-private` standalone profile (AI tools + private
      # secrets) so the VM is a full private workstation on ARM.
      homeModules = privateModules;
    };
  };
in
{
  inherit hosts darwinHosts nixosHosts;

  homeConfigurations = lib.mapAttrs (
    _: host:
    mkHome {
      inherit (host) system;
      user = host.user or defaultUser;
      modules = host.modules or [ ];
    }
  ) hosts;

  darwinConfigurations = lib.mapAttrs (_: mkDarwin) darwinHosts;

  nixosConfigurations = lib.mapAttrs (
    _: host:
    mkNixos {
      inherit (host) system hostModule;
      homeModules = host.homeModules or fullModules;
      user = host.user or defaultUser;
    }
  ) nixosHosts;
}
