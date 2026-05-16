{
  description = "My Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
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

      mkHome =
        system: modules:
        let
          pkgs = import nixpkgs {
            inherit system;

            config = {
              allowUnfreePredicate =
                pkg:
                builtins.elem (pkg.pname or pkg.name) [
                  "claude-code"
                ];
            };
          };

          pkgs-unstable = import nixpkgs-unstable {
            inherit system;

            config = {
              allowUnfreePredicate =
                pkg:
                builtins.elem (pkg.pname or pkg.name) [
                  "claude-code"
                ];
            };
          };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit agenix pkgs-unstable user;
          };

          modules = [
            nixvim.homeModules.nixvim
            agenix.homeManagerModules.default

            {
              home.username = username;

              home.homeDirectory =
                if builtins.match ".*darwin" system != null then "/Users/${username}" else "/home/${username}";

              home.stateVersion = "25.11";
            }
          ]
          ++ modules;
        };
    in
    {
      homeConfigurations = {
        linux-x86 = mkHome "x86_64-linux" [
          ./profiles/base.nix
          ./profiles/linux.nix
        ];

        linux-x86-ai = mkHome "x86_64-linux" [
          ./profiles/base.nix
          ./profiles/linux.nix
          ./profiles/ai.nix
        ];

        linux-x86-private = mkHome "x86_64-linux" [
          ./profiles/base.nix
          ./profiles/linux.nix
          ./profiles/ai.nix
          ./profiles/private.nix
        ];

        linux-arm = mkHome "aarch64-linux" [
          ./profiles/base.nix
          ./profiles/linux-arm.nix
        ];

        linux-arm-private = mkHome "aarch64-linux" [
          ./profiles/base.nix
          ./profiles/linux-arm.nix
          ./profiles/ai.nix
          ./profiles/private.nix
        ];

        apple = mkHome "aarch64-darwin" [
          ./profiles/base.nix
          ./profiles/apple.nix
        ];

        apple-private = mkHome "aarch64-darwin" [
          ./profiles/base.nix
          ./profiles/apple.nix
          ./profiles/private.nix
          ./profiles/ai.nix
        ];
      };
    };
}
