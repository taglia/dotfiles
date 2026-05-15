{
  description = "My Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nixvim, ... }:
    let
      username = "taglia";

      mkHome =
        system: modules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
          };

          modules =
            [
	      nixvim.homeModules.nixvim

              {
                home.username = username;

                home.homeDirectory =
                  if builtins.match ".*darwin" system != null
                  then "/Users/${username}"
                  else "/home/${username}";

                home.stateVersion = "25.11";
              }
            ]
            ++ modules;
        };
    in {
      homeConfigurations = {
        linux-x86 =
          mkHome "x86_64-linux" [
            ./profiles/base.nix
            ./profiles/linux.nix
          ];

        linux-x86-private =
          mkHome "x86_64-linux" [
            ./profiles/base.nix
            ./profiles/linux.nix
            ./profiles/private.nix
          ];

        linux-arm =
          mkHome "aarch64-linux" [
            ./profiles/base.nix
            ./profiles/linux-arm.nix
          ];

        linux-arm-private =
          mkHome "aarch64-linux" [
            ./profiles/base.nix
            ./profiles/linux-arm.nix
            ./profiles/private.nix
          ];

        apple =
          mkHome "aarch64-darwin" [
            ./profiles/base.nix
            ./profiles/apple.nix
          ];

        apple-private =
          mkHome "aarch64-darwin" [
            ./profiles/base.nix
            ./profiles/apple.nix
            ./profiles/private.nix
          ];

        apple-private-ai =
          mkHome "aarch64-darwin" [
            ./profiles/base.nix
            ./profiles/apple.nix
            ./profiles/private.nix
            ./profiles/ai.nix
          ];
      };
    };
}

