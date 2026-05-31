{
  description = "NixOS configuration for the Open Computing Facility";

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "nixos-26.05";
    };

    nixpkgs-deprecated = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "nixos-25.11";
    };

    nixpkgs-unstable = {
      type = "github";
      owner = "nixos";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };

    systems = {
      type = "github";
      owner = "nix-systems";
      repo = "default";
      ref = "main";
    };

    colmena = {
      type = "github";
      owner = "zhaofengli";
      repo = "colmena";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      type = "github";
      owner = "ryantm";
      repo = "agenix";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      type = "github";
      owner = "oddlama";
      repo = "agenix-rekey";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      type = "github";
      owner = "nix-community";
      repo = "disko";
      ref = "latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      type = "github";
      owner = "nix-community";
      repo = "nix-index-database";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ocflib = {
      type = "github";
      owner = "ocf";
      repo = "ocflib";
      ref = "master";
    };

    ocf-sync-etc = {
      type = "github";
      owner = "ocf";
      repo = "etc";
      ref = "master";
    };

    ocf-pam-trimspaces = {
      type = "github";
      owner = "ocf";
      repo = "pam_trimspaces";
      ref = "master";
    };

    ocf-utils = {
      type = "github";
      owner = "ocf";
      repo = "utils";
      ref = "master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ocflib.follows = "ocflib";
    };

    wayout = {
      type = "github";
      owner = "ocf";
      repo = "wayout";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ocf-cosmic-applets = {
      type = "github";
      owner = "ocf";
      repo = "cosmic-applets";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ocf-jukebox = {
      url = "github:ocf/jukebox-django";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niks3 = {
      type = "github";
      owner = "Mic92";
      repo = "niks3";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-deprecated,
      nixpkgs-unstable,
      systems,
      colmena,
      agenix,
      agenix-rekey,
      disko,
      nix-index-database,
      ocflib,
      ocf-sync-etc,
      ocf-pam-trimspaces,
      ocf-utils,
      wayout,
      ocf-cosmic-applets,
      ocf-jukebox,
      niks3,
    }@inputs:
    let
      # ============== #
      # Things to edit #
      # ============== #

      overlays = [
        self.overlays.default
        ocflib.overlays.default
        ocf-sync-etc.overlays.default
        ocf-pam-trimspaces.overlays.default
        nix-index-database.overlays.nix-index
        agenix-rekey.overlays.default
      ];

      customModules = (
        with nixpkgs.lib; filter (hasSuffix ".nix") (filesystem.listFilesRecursive ./modules)
      );

      commonModules = customModules ++ [
        ./profiles/base.nix
        agenix.nixosModules.default
        agenix-rekey.nixosModules.default
        disko.nixosModules.disko
        niks3.nixosModules.default
        niks3.nixosModules.niks3-auto-upload
        wayout.nixosModules.default
      ];

      # NOTE: all hosts will be sharing the same ocf nix modules in this
      # repository regardless of what pkgs is set to
      defaultPkgsFor = pkgsStableFor;
      overridePkgsFor = {
        # example:
        # hostname = pkgsUnstableFor;

        # even after adding:
        # nixpkgs.config.permittedInsecurePackages = [
        #   "nodejs-20.20.2"
        #   "nodejs-slim-20.20.2"
        #   "nodejs-20.20.2-source"
        # ];
        #
        # to ./modules/matrix/discord-bridge.nix, scootaloo still fails to
        # build with:
        # "error: attribute 'nodeAppDir' missing"
        #
        # we will keep scootaloo on nixos-25.11 for now until
        # matrix-appservice-discord is updated to work with nixos-26.05.
        #
        # see: https://github.com/NixOS/nixpkgs/issues/515284
        scootaloo = pkgsDeprecatedFor;
      };

      defaultSystem = "x86_64-linux";
      overrideSystem = {
        # example:
        # hostname = "aarch64-linux";
        overheat = "aarch64-linux";
      };

      # ============== #
      # Glue/Internals #
      # ============== #

      # takes in a system like "x86_64-linux", and returns the pkgs for that
      # system
      pkgsStableFor =
        system:
        import nixpkgs {
          inherit overlays system;
          config = {
            allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "code"
                "claude-code"
                "dwarf-fortress"
                "google-chrome"
                "helvetica-neue-lt-std" # tornado
                "nvidia-settings"
                "nvidia-x11"
                "nvidia-kernel-modules"
                "steam"
                "steam-unwrapped"
                "vscode"
                "zoom"
                "drawio"
                "datagrip"
                "davinci-resolve"
                "1password"
                "1password-cli"
              ];
          };
        };

      pkgsUnstableFor =
        system:
        import nixpkgs-unstable {
          inherit overlays system;
        };

      pkgsDeprecatedFor =
        system:
        import nixpkgs-deprecated {
          inherit overlays system;
        };

      forAllSystems = fn: nixpkgs.lib.genAttrs (import systems) (system: fn (defaultPkgsFor system));

      pkgsForOverrideSystems = nixpkgs.lib.mapAttrs (_: defaultPkgsFor) overrideSystem;
      pkgsForOverridePkgs = nixpkgs.lib.mapAttrs (
        name: pkgsFor: pkgsFor (overrideSystem.${name} or defaultSystem)
      ) overridePkgsFor;

      readGroup =
        group:
        nixpkgs.lib.mapAttrs' (filename: _: {
          name = nixpkgs.lib.nameFromURL filename ".";
          value = {
            inherit group;
            modules = [ ./hosts/${group}/${filename} ];
          };
        }) (builtins.readDir ./hosts/${group});

      hosts = nixpkgs.lib.concatMapAttrs (group: _: readGroup group) (builtins.readDir ./hosts);

      deploy-user = "ocf-nix-deploy-user";
      colmenaHosts = builtins.mapAttrs (
        host:
        { modules, group }:
        {
          imports = commonModules ++ modules;
          deployment.tags = [ group ];
          deployment.targetHost = "${host}.ocf.berkeley.edu";
          # TODO: Think of a less ugly way of doing this
          deployment.targetUser =
            nixpkgs.lib.mkIf self.colmenaHive.nodes.${host}.config.ocf.managed-deployment.enable
              deploy-user;
          networking.hostName = "${host}";
          networking.hostId = builtins.substring 0 8 (builtins.hashString "sha1" "${host}");
        }
      ) hosts;
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      colmenaHive = colmena.lib.makeHive (
        colmenaHosts
        // {
          meta = {
            nixpkgs = defaultPkgsFor defaultSystem;
            nodeNixpkgs = pkgsForOverrideSystems // pkgsForOverridePkgs;
            specialArgs = {
              inherit self inputs;
              # pkgs-unstable exposes the packages from the nixpkgs-unstable input
              # this should only be used as a *temporary* measure when the version of
              # a package in nixpkgs stable is not sufficiently updated
              pkgs-unstable = pkgsUnstableFor defaultSystem;
              pkgs-deprecated = pkgsDeprecatedFor defaultSystem;
            };
            nodeSpecialArgs = nixpkgs.lib.mapAttrs (name: system: {
              pkgs-unstable = pkgsUnstableFor system;
              pkgs-deprecated = pkgsDeprecatedFor system;
            }) overrideSystem;
          };
        }
      );

      autoDeploy =
        let
          # returns the value of a managed-deployment option (given as a string containing the option name) for the given node
          getOptionForNode =
            option: node: self.colmenaHive.nodes.${node}.config.ocf.managed-deployment.${option};

          # returns a list of the MAC addresses for the given list of nodes with automated deploy enabled
          # hosts that do not have mac-address set will be gracefully ignored
          getMACs =
            nodes:
            builtins.filter (mac: mac != "") (builtins.map (node: getOptionForNode "mac-address" node) nodes);
        in
        {
          # list of nodes with automated deploy enabled, to be consumed by github actions
          nodes = builtins.filter (node: getOptionForNode "automated-deploy" node) (
            builtins.attrNames self.colmenaHive.nodes
          );

          # list of mac addresses of nodes that github actions should wake up on deploy
          MACs = getMACs self.autoDeploy.nodes;

          # attribute set combining automatedDeployNodes and automatedDeployNodeMACs
          # get json with `nix eval .#autoDeploy.nodesWithMACs --json`!
          # TODO: script to wake up hosts with this
          nodesWithMACs = nixpkgs.lib.listToAttrs (
            nixpkgs.lib.zipListsWith (name: value: {
              inherit name value;
            }) self.autoDeploy.nodes self.autoDeploy.MACs
          );
        };

      overlays.default = final: prev: {
        # Patch nginx for multiple CVEs disclosed 2026-05-13, until nixos-25.11
        # channel advances past the fix (nixpkgs#520076).
        # Remove this overlay once flake.lock points to a nixpkgs with nginx >= 1.30.1.
        nginx = prev.nginx.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            (final.fetchpatch {
              name = "CVE-2026-40460.patch";
              url = "https://github.com/nginx/nginx/commit/f37ec3e5d4f527e52ed5b25951ad8aa7d1ff6266.patch";
              hash = "sha256-++hYEzMUkl3mbBMaffR2LQTYMxOR/YziNkYCVyhw2Qg=";
            })
            (final.fetchpatch {
              name = "CVE-2026-40701.patch";
              url = "https://github.com/nginx/nginx/commit/71841dcedfdf46048ef5e25413fdf97a66957913.patch";
              hash = "sha256-FzNZpEwIj76r5dpqEP6TgpSc1ywcW7ZOEQpFpwI/YZw=";
            })
            (final.fetchpatch {
              name = "CVE-2026-42934.patch";
              url = "https://github.com/nginx/nginx/commit/696a7f1b9198d576e6a59c1655b746fbf06561cf.patch";
              hash = "sha256-/vjyEGysPv5VK4TZmk/gtIg9Zc5ogUXMwpBfBwe55Bc=";
            })
            (final.fetchpatch {
              name = "CVE-2026-42945.patch";
              url = "https://github.com/nginx/nginx/commit/2046b45aa0c6e712c216b9075886f3f26e9b4ca9.patch";
              hash = "sha256-VK9CXgrCIqORsaRivTZBmkoLyQhbZ07ss6nAbLNvfJM=";
            })
            (final.fetchpatch {
              name = "CVE-2026-42946.patch";
              url = "https://github.com/nginx/nginx/commit/baef7fdac28e4e1fe26509b50b8d15603393e28e.patch";
              hash = "sha256-Z1naMxxiVuDbUcvX3PiIK4CMuSSpUyzPqjix9GTwHmk=";
            })
            (final.fetchpatch {
              name = "CVE-2026-42946-part-2.patch";
              url = "https://github.com/nginx/nginx/commit/39d7d0ba0799fcff6baee52b6525f45739593cfd.patch";
              hash = "sha256-6PwV0iz4kQGGBwVk9129aH+TFzbSx3QSVpp22AoKQY4=";
            })
          ];
        });

        ocf-utils = ocf-utils.packages.${final.stdenv.hostPlatform.system}.default;
        ocf-jukebox = ocf-jukebox.packages.${final.stdenv.hostPlatform.system}.default;
        plasma-applet-commandoutput = final.callPackage ./pkgs/plasma-applet-commandoutput.nix { };
        catppuccin-sddm = final.qt6Packages.callPackage ./pkgs/catppuccin-sddm.nix { };
        ocf-cosmic-applets = ocf-cosmic-applets.packages.${final.stdenv.hostPlatform.system}.default;
        ocf-cosmic-greeter = final.callPackage ./pkgs/ocf-cosmic-greeter.nix { };
        ocf-hplip = final.callPackage ./pkgs/ocf-hplip.nix { };
        ocf-niks3-push = final.callPackage ./pkgs/ocf-niks3-push {
          niks3 = niks3.packages.${final.stdenv.hostPlatform.system}.default;
        };
      };

      agenix-rekey = agenix-rekey.configure {
        userFlake = self;
        nixosConfigurations = self.colmenaHive.nodes;
      };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.age
            pkgs.agenix-rekey
            pkgs.age-plugin-fido2-hmac
            pkgs.wol
            pkgs.nixfmt-tree
            pkgs.nix-fast-build
            colmena.packages.${pkgs.stdenv.hostPlatform.system}.colmena
          ];
        };
        deploy = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.openssh
            pkgs.wol
            pkgs.nixfmt-tree
            pkgs.nix-fast-build
            colmena.packages.${pkgs.stdenv.hostPlatform.system}.colmena
          ];
        };
      });

      nixosConfigurations = builtins.mapAttrs (
        host: colmenaConfig:
        let
          system = overrideSystem.${host} or defaultSystem;
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          pkgs = defaultPkgsFor system;
          modules = colmenaConfig.imports;
          specialArgs = {
            inherit inputs;
            pkgs-unstable = pkgsUnstableFor system;
            pkgs-deprecated = pkgsDeprecatedFor system;
          };
        }
      ) colmenaHosts;
    };
}
