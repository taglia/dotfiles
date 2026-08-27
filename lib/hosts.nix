# Host table and the builders that turn each entry into a Home Manager,
# nix-darwin or NixOS configuration. Kept out of flake.nix so the flake outputs
# stay thin; flake.nix wires inputs in and re-exports the results.
#
# `defaultUser` and `commonSpecialArgs` are passed in from flake.nix (the flake
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
  nix-homebrew,
  commonSpecialArgs,
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

        # Supply `user` per Home Manager user rather than through
        # (extra)specialArgs: specialArgs are shared by every HM user inside
        # one darwin system eval, so a multi-user host (mkDarwin's
        # extraHomeUsers) would leak the primary identity into the other
        # users' modules. specialArgs shadow _module.args, so mkDarwin must
        # not put `user` in extraSpecialArgs.
        _module.args.user = user;
      }

      ../profiles/base.nix
      platformModule
    ]
    ++ modules;

  # `user` deliberately stays out of the Home Manager (extra)specialArgs in
  # all three builders: HM modules receive it per user via _module.args (see
  # mkHomeModules), which a `user` in specialArgs would shadow — with the
  # primary identity — for every user of a multi-user darwin host.
  homeExtraSpecialArgs = builtins.removeAttrs commonSpecialArgs [ "user" ];

  mkHome =
    {
      system,
      modules ? [ ],
      user ? defaultUser,
      secretsMachine ? null,
    }:
    home-manager.lib.homeManagerConfiguration {
      # Reuse the nixpkgs flake's shared per-system instantiation instead of
      # importing a fresh copy per home configuration.
      pkgs = nixpkgs.legacyPackages.${system};

      extraSpecialArgs = homeExtraSpecialArgs // {
        inherit secretsMachine;
      };

      modules = mkHomeModules { inherit system modules user; };
    };

  mkDarwin =
    {
      system,
      modules ? [ ],
      user ? defaultUser,
      secretsMachine ? null,
      # Additional Home Manager users switched together with the system
      # (username -> { user, modules ? [ ] }), so one `darwin-rebuild switch`
      # updates every account's home from the same generation: package sets
      # stay aligned and a single GC root covers them all.
      extraHomeUsers ? { },
    }:
    nix-darwin.lib.darwinSystem {
      inherit system;

      specialArgs = commonSpecialArgs // {
        inherit user;
      };

      modules = [
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
        ../modules/darwin/aerospace.nix
        ../modules/darwin/core.nix
        ../modules/darwin/desktop.nix
        ../modules/darwin/homebrew.nix
        ../modules/darwin/input.nix
        ../modules/darwin/packages.nix
        ../modules/darwin/system.nix

        {
          # useUserPackages installs each user's home.packages through
          # users.users.<name>.packages, so every HM user needs a (metadata
          # only, account creation is not attempted) users.users entry;
          # core.nix declares the primary user's.
          users.users = lib.mapAttrs (username: _: {
            home = "/Users/${username}";
          }) extraHomeUsers;

          # Same fish login shell for the extra home users as core.nix sets
          # for the primary user (dscl as root, so /etc/shells is not
          # consulted; fish is on the system profile path either way).
          system.activationScripts.postActivation.text = lib.mkAfter (
            lib.concatMapStrings (username: ''
              dscl . -create /Users/${username} UserShell /run/current-system/sw/bin/fish
            '') (builtins.attrNames extraHomeUsers)
          );

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = homeExtraSpecialArgs // {
              inherit secretsMachine;
            };
            users = lib.mapAttrs (_: u: {
              imports = mkHomeModules {
                inherit system;
                inherit (u) user;
                modules = u.modules or [ ];
              };
            }) ({ ${user.username} = { inherit user modules; }; } // extraHomeUsers);
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
      secretsMachine ? null,
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = commonSpecialArgs // {
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
            extraSpecialArgs = homeExtraSpecialArgs // {
              inherit secretsMachine;
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

  # The separate macOS admin account (owns the Homebrew prefix, see
  # modules/darwin/homebrew.nix). Its home rides along with the mbp system
  # switch (darwinHosts.mbp.extraHomeUsers below); the standalone mbp-admin
  # target exists for switching it on its own.
  adminUser = defaultUser // {
    username = defaultUser.adminUsername or "richie";
  };

  # Module set for the admin account's home: the dev setup plus the
  # interactive-shell Homebrew trust file (essential for the admin, who owns
  # the prefix and runs brew).
  adminModules = fullModules ++ [ ../modules/home/homebrew-trust.nix ];

  hosts = {
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
      secretsMachine = "dev-vm";
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
      secretsMachine = "openclaw-hetzner";
      user = defaultUser // {
        username = "openclaw";
      };
      modules = fullModules ++ [
        ../profiles/private.nix
        ../profiles/ai.nix
      ];
    };

    linux-arm = {
      system = "aarch64-linux";
      modules = fullModules;
    };

    linux-minimal-arm = {
      system = "aarch64-linux";
      modules = [ ];
    };

    # Standalone Home Manager target for the admin account (adminUser above):
    # the daily dev setup without private secrets or the mbp-only extras
    # (sketchybar, entertainment). Normally not needed — `darwin-rebuild
    # switch` already switches this home via darwinHosts.mbp.extraHomeUsers —
    # but usable on its own while logged in as that user. A per-host user
    # override like this (not identity.nix, which redefines the identity for
    # EVERY target and breaks the primary user's switches while present) is
    # the mechanism for a second user on the same machine, like linux-aws and
    # linux-openclaw below.
    mbp-admin = {
      system = "aarch64-darwin";
      user = adminUser;
      modules = adminModules;
    };

    mbp = {
      system = "aarch64-darwin";
      secretsMachine = "mbp";
      modules = fullModules ++ [
        ../profiles/ai.nix
        ../profiles/private.nix
        # Declarative brew tap-trust for interactive shells (replaces the
        # hand-written ~/.config/homebrew/trust.json).
        ../modules/home/homebrew-trust.nix
        # Games and terminal toys (cmatrix, asciiquarium, nethack) plus
        # chess-tui wired to gnuchess --uci as its bot engine. Kept on the
        # mbp profile only, so the other hosts stay lean.
        ../modules/home/entertainment.nix
        # Darwin-only: SketchyBar runs as a user launchd agent and its HM
        # module asserts a Darwin platform, so keep it out of the Linux
        # homeConfigurations by importing it here rather than in
        # profiles/base.nix or profiles/darwin.nix.
        ../modules/home/sketchybar.nix
        # Terminal email (aerc). mbp-only, matching mail-accounts.age's
        # recipient list in secrets.nix; the accounts themselves live in
        # that secret (see the module header).
        ../modules/home/mail.nix
      ];
    };
  };

  darwinHosts = {
    # The admin account's home is switched together with the system (same
    # module set as the standalone mbp-admin target), keeping both users'
    # package sets aligned in one generation and under one GC root.
    mbp = hosts.mbp // {
      extraHomeUsers = {
        ${adminUser.username} = {
          user = adminUser;
          modules = adminModules;
        };
      };
    };
  };

  nixosHosts = {
    utm-vm = {
      system = "aarch64-linux";
      secretsMachine = "utm-vm";
      hostModule = ../hosts/utm-vm;
      # Match the `linux-private` standalone profile (AI tools + private
      # secrets) so the VM is a full private workstation on ARM.
      homeModules = privateModules;
    };
    ec2-x86-vm = {
      system = "x86_64-linux";
      # No secretsMachine: this host does not import profiles/private.nix. If
      # it ever gets private secrets, add a machine entry to
      # secrets-machines.nix and set secretsMachine to its name here.
      hostModule = ../hosts/ec2-x86-vm;
      # Dev tooling + AI tools (no private secrets), so the VM is a full
      # workstation without the private agenix profile.
      homeModules = fullModules ++ [ ../profiles/ai.nix ];
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
      secretsMachine = host.secretsMachine or null;
    }
  ) hosts;

  # mkDarwin's parameters mirror the host attrset keys (system, modules,
  # user, secretsMachine), so the attrset can be applied directly.
  darwinConfigurations = lib.mapAttrs (_: mkDarwin) darwinHosts;

  nixosConfigurations = lib.mapAttrs (
    _: host:
    mkNixos {
      inherit (host) system hostModule;
      homeModules = host.homeModules or fullModules;
      user = host.user or defaultUser;
      secretsMachine = host.secretsMachine or null;
    }
  ) nixosHosts;
}
