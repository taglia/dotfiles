{
  description = "My Home Manager configuration";

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
      ...
    }:
    let
      defaultUser = {
        username = "taglia";
        githubUsername = "taglia";
        email = "612306+taglia@users.noreply.github.com";
      };

      username = defaultUser.username;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      mkHomeModules =
        {
          pkgs,
          modules ? [ ],
          user ? defaultUser,
        }:
        let
          isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
          platformModule = if isDarwin then ./profiles/darwin.nix else ./profiles/linux.nix;
          username = user.username;
        in
        [
          nixvim.homeModules.nixvim
          agenix.homeManagerModules.default

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

          modules = mkHomeModules { inherit pkgs modules user; };
        };

      mkDarwin =
        {
          system,
          modules ? [ ],
          darwinFeatures ? { },
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;

          specialArgs = homeSpecialArgs // {
            inherit darwinFeatures;
          };

          modules = [
            home-manager.darwinModules.home-manager
            ./modules/darwin/aerospace.nix
            ./modules/darwin/homebrew.nix
            ./modules/darwin/packages.nix
            ./modules/darwin/settings.nix

            (
              { pkgs, ... }:
              {
                system.stateVersion = 6;
                system.primaryUser = username;

                nix.settings.experimental-features = [
                  "nix-command"
                  "flakes"
                ];

                programs.fish.enable = true;

                security.pam.services.sudo_local = {
                  # Use Touch ID and Apple Watch for sudo when macOS allows it.
                  touchIdAuth = true;

                  # Keep biometric sudo working from inside tmux/screen sessions.
                  reattach = true;
                };

                environment.shells = [
                  pkgs.bashInteractive
                  pkgs.fish
                  pkgs.zsh
                ];

                environment.systemPackages = [
                  home-manager.packages.${system}.home-manager
                ];

                users.users.${username} = {
                  home = "/Users/${username}";
                };

                # Keep the primary user's login shell on the stable nix-darwin
                # system profile path. The old standalone Home Manager path
                # under ~/.nix-profile can disappear once Home Manager is
                # integrated into nix-darwin.
                system.activationScripts.primaryUserShell.text = ''
                  dscl . -create /Users/${username} UserShell /run/current-system/sw/bin/fish
                '';

                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = homeSpecialArgs;
                  users.${username}.imports = mkHomeModules { inherit pkgs modules; };
                };
              }
            )
          ];
        };

      fullModules = [
        ./modules/home/dev.nix
        ./modules/home/packages-dev.nix
        ./modules/home/media.nix
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
          modules = fullModules ++ [
            ./profiles/ai.nix
            ./profiles/private.nix
          ];
        };

        linux-minimal.system = "x86_64-linux";

        linux-aws = {
          system = "x86_64-linux";
          user = defaultUser // {
            username = "admin";
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
          darwinFeatures = {
            restartAfterPowerFailure = false;
          };
          modules = fullModules ++ [
            ./profiles/ai.nix
            ./profiles/private.nix
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
    in
    {
      inherit homeConfigurations darwinConfigurations;

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
        in
        homeChecks // darwinChecks
      );
    };
}
