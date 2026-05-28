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
      user = {
        username = "taglia";
        githubUsername = "taglia";
        email = "612306+taglia@users.noreply.github.com";
      };

      username = user.username;

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
        }:
        let
          isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
          platformModule = if isDarwin then ./profiles/darwin.nix else ./profiles/linux.nix;
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
          user
          inputs
          ;
      };

      mkHome =
        {
          system,
          modules ? [ ],
        }:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = homeSpecialArgs;

          modules = mkHomeModules { inherit pkgs modules; };
        };

      mkDarwin =
        {
          system,
          modules ? [ ],
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;

          specialArgs = homeSpecialArgs;

          modules = [
            home-manager.darwinModules.home-manager
            ./modules/darwin/homebrew.nix
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
        ./modules/dev.nix
        ./modules/packages-dev.nix
        ./modules/media.nix
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
          ];
        };

        mbp-home = mbp;
      };

      homeConfigurations = nixpkgs.lib.mapAttrs (_: mkHome) hosts;

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
