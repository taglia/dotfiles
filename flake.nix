{
  description = "My Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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

      mkHome =
        {
          system,
          modules ? [ ],
        }:
        let
          pkgs = import nixpkgs { inherit system; };
          isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
          platformModule = if isDarwin then ./profiles/darwin.nix else ./profiles/linux.nix;
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit
              agenix
              nixpkgs-unstable
              user
              inputs
              ;
          };

          modules = [
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
        };

      fullModules = [
        ./modules/dev.nix
        ./modules/packages-dev.nix
        ./modules/media.nix
      ];

      hosts = {
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
      };

      homeConfigurations = nixpkgs.lib.mapAttrs (_: mkHome) hosts;
    in
    {
      inherit homeConfigurations;

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
        nixpkgs.lib.genAttrs (builtins.filter (name: hosts.${name}.system == system) (
          builtins.attrNames hosts
        )) (name: homeConfigurations.${name}.activationPackage)
      );
    };
}
