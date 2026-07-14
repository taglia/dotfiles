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
      nixpkgs-unstable,
      home-manager,
      nix-darwin,
      nixvim,
      agenix,
      nix-index-database,
      ...
    }:
    let
      defaultUser = {
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

      mkHomeModules =
        {
          system,
          modules ? [ ],
          user ? defaultUser,
        }:
        let
          isDarwin = nixpkgs.lib.hasSuffix "-darwin" system;
          platformModule = if isDarwin then ./profiles/darwin.nix else ./profiles/linux.nix;
          username = user.username;
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

          ./profiles/base.nix
          platformModule
        ]
        ++ modules;

      homeSpecialArgs = {
        inherit
          agenix
          nixpkgs-unstable
          inputs
          ;
        user = defaultUser;
      };

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
            ./modules/darwin/aerospace.nix
            ./modules/darwin/core.nix
            ./modules/darwin/desktop.nix
            ./modules/darwin/homebrew.nix
            ./modules/darwin/input.nix
            ./modules/darwin/packages.nix
            ./modules/darwin/system.nix

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
        ./modules/home/dev.nix
        ./modules/home/packages-dev.nix
        ./modules/home/media.nix
      ];

      # The Home Manager module set shared by the standalone `linux-private`
      # configuration and the `utm-vm` NixOS host, so the VM gets the same user
      # environment (AI tools + private agenix secrets) as `linux-private`, just
      # built for aarch64-linux instead of x86_64-linux. Architecture is handled
      # by mkNixos importing nixpkgs with the host's `system`, so nothing extra
      # is needed here for ARM.
      privateModules = fullModules ++ [
        ./profiles/ai.nix
        ./profiles/private.nix
      ];

      hosts = rec {
        linux = {
          system = "x86_64-linux";
          modules = fullModules;
        };

        linux-ai = {
          system = "x86_64-linux";
          modules = fullModules ++ [ ./profiles/ai.nix ];
        };

        linux-private = {
          system = "x86_64-linux";
          modules = privateModules;
        };

        linux-minimal.system = "x86_64-linux";

        linux-aws = {
          system = "x86_64-linux";
          user = defaultUser // {
            username = "admin";
          };
          modules = fullModules ++ [ ./profiles/ai.nix ];
        };

        linux-openclaw = {
          system = "x86_64-linux";
          user = defaultUser // {
            username = "openclaw";
          };
          modules = fullModules ++ [ ./profiles/ai.nix ];
        };

        linux-arm = {
          system = "aarch64-linux";
          modules = fullModules;
        };

        linux-minimal-arm.system = "aarch64-linux";

        mbp = {
          system = "aarch64-darwin";
          modules = fullModules ++ [
            ./profiles/ai.nix
            ./profiles/private.nix
            # Darwin-only: SketchyBar runs as a user launchd agent and its HM
            # module asserts a Darwin platform, so keep it out of the Linux
            # homeConfigurations by importing it here rather than in
            # profiles/base.nix or profiles/darwin.nix.
            ./modules/home/sketchybar.nix
          ];
        };

        mbp-home = mbp;
      };

      homeConfigurations = nixpkgs.lib.mapAttrs (
        _: host:
        mkHome {
          inherit (host) system;
          user = host.user or defaultUser;
          modules = host.modules or [ ];
        }
      ) hosts;

      darwinHosts = {
        mbp = hosts.mbp;
      };

      darwinConfigurations = nixpkgs.lib.mapAttrs (_: mkDarwin) darwinHosts;

      nixosHosts = {
        utm-vm = {
          system = "aarch64-linux";
          hostModule = ./hosts/utm-vm;
          # Match the `linux-private` standalone profile (AI tools + private
          # secrets) so the VM is a full private workstation on ARM.
          homeModules = privateModules;
        };
      };

      nixosConfigurations = nixpkgs.lib.mapAttrs (
        _: host:
        mkNixos {
          inherit (host) system hostModule;
          homeModules = host.homeModules or fullModules;
          user = host.user or defaultUser;
        }
      ) nixosHosts;
    in
    {
      inherit homeConfigurations darwinConfigurations nixosConfigurations;

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.writeShellApplication {
          name = "nixfmt-dotfiles";
          runtimeInputs = [ pkgs.nixfmt ];
          text = ''
            if [ "$#" -gt 0 ]; then
              exec nixfmt "$@"
            fi

            find . -path ./.git -prune -o -name '*.nix' -type f -print0 | xargs -0 nixfmt
          '';
        }
      );

      checks = forAllSystems (
        system:
        let
          homeChecks = nixpkgs.lib.genAttrs (builtins.filter (name: hosts.${name}.system == system) (
            builtins.attrNames hosts
          )) (name: homeConfigurations.${name}.activationPackage);

          darwinChecks = builtins.listToAttrs (
            map (name: {
              name = "darwin-${name}";
              value = darwinConfigurations.${name}.system;
            }) (builtins.filter (name: darwinHosts.${name}.system == system) (builtins.attrNames darwinHosts))
          );

          nixosChecks = builtins.listToAttrs (
            map (name: {
              name = "nixos-${name}";
              value = nixosConfigurations.${name}.config.system.build.toplevel;
            }) (builtins.filter (name: nixosHosts.${name}.system == system) (builtins.attrNames nixosHosts))
          );
        in
        homeChecks // darwinChecks // nixosChecks
      );
    };
}
