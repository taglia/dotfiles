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
        system: extraModules:
        let
          pkgs = import nixpkgs { inherit system; };
          isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
          platformModule = if isDarwin then ./profiles/apple.nix else ./profiles/linux.nix;
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
          ++ extraModules;
        };

      homeConfigurations = {
        linux = mkHome "x86_64-linux" [ ];

        linux-ai = mkHome "x86_64-linux" [
          ./profiles/ai.nix
        ];

        linux-private = mkHome "x86_64-linux" [
          ./profiles/ai.nix
          ./profiles/private.nix
        ];

        linux_arm = mkHome "aarch64-linux" [ ];

        mbp = mkHome "aarch64-darwin" [
          ./profiles/ai.nix
          ./profiles/private.nix
        ];
      };
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

      checks = {
        x86_64-linux = {
          linux = homeConfigurations.linux.activationPackage;
          linux-ai = homeConfigurations.linux-ai.activationPackage;
          linux-private = homeConfigurations.linux-private.activationPackage;
        };

        aarch64-linux = {
          linux_arm = homeConfigurations.linux_arm.activationPackage;
        };

        aarch64-darwin = {
          mbp = homeConfigurations.mbp.activationPackage;
        };
      };
    };
}
