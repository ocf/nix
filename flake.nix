{
  description = "NixOS configuration for the Open Computing Facility";

  inputs = {
    nixpkgs = {
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
    };

    agenix-rekey = {
      type = "github";
      owner = "oddlama";
      repo = "agenix-rekey";
      ref = "main";
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

    # trying to install home-manager module by default? need to test?
    home-manager = {
      type = "github";
      owner = "nix-community";
      repo = "home-manager";
      ref = "master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      type = "github";
      owner = "hyprwm";
      repo = "Hyprland";
      ref = "main";
    };

    hyprland-plugins = {
      type = "github";
      owner = "hyprwm";
      repo = "Hyprland";
      ref = "main";
      inputs.hyprland.follows = "hyprland";
    };

  };

  outputs =
    { self
    , nixpkgs
    , systems
    , colmena
    , agenix
    , agenix-rekey
    , disko
    , nix-index-database
    , ocflib
    , ocf-sync-etc
    , ocf-pam-trimspaces
    , ocf-utils
    , home-manager
    , hyprland
    , hyprland-plugins
    , wayout
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
	hyprland.overlays.default
	hyprland-plugins.overlays.default
      ];

      customModules =
        (with nixpkgs.lib; filter (hasSuffix ".nix") (filesystem.listFilesRecursive ./modules));

      commonModules = customModules ++ [
        ./profiles/base.nix
        agenix.nixosModules.default
        agenix-rekey.nixosModules.default
        disko.nixosModules.disko
	hyprland.nixosModules.default
      ];

      defaultSystem = "x86_64-linux";
      overrideSystem = { overheat = "aarch64-linux"; };

      # ============== #
      # Glue/Internals #
      # ============== #

      pkgsFor = system: import nixpkgs {
        inherit overlays system;
        config = { allowUnfree = true; };
      };

      forAllSystems = fn: nixpkgs.lib.genAttrs
        (import systems)
        (system: fn (pkgsFor system));

      readGroup = group: nixpkgs.lib.mapAttrs'
        (filename: _: {
          name = nixpkgs.lib.nameFromURL filename ".";
          value = {
            inherit group;
            modules = [ ./hosts/${group}/${filename} ];
          };
        })
        (builtins.readDir ./hosts/${group});

      hosts = nixpkgs.lib.concatMapAttrs
        (group: _: readGroup group)
        (builtins.readDir ./hosts);

      deploy-user = "ocf-nix-deploy-user";
      colmenaHosts = builtins.mapAttrs
        (host: { modules, group }: {
          imports = commonModules ++ modules;
          deployment.tags = [ group ];
          deployment.targetHost = "${host}.ocf.berkeley.edu";
          # TODO: Think of a less ugly way of doing this
          deployment.targetUser = nixpkgs.lib.mkIf self.colmenaHive.nodes.${host}.config.ocf.managed-deployment.enable deploy-user;
        })
        hosts;
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);

      colmenaHive = colmena.lib.makeHive (colmenaHosts // {
        meta = {
          nixpkgs = pkgsFor defaultSystem;
          nodeNixpkgs = nixpkgs.lib.mapAttrs (name: pkgsFor) overrideSystem;
          specialArgs = { inherit inputs; };
        };
      });

      overlays.default = final: prev: {
        ocf-utils = ocf-utils.packages.${final.system}.default;
        ocf-wayout = wayout.packages.${final.system}.default;
        plasma-applet-commandoutput = final.callPackage ./pkgs/plasma-applet-commandoutput.nix { };
        catppuccin-sddm = final.qt6Packages.callPackage ./pkgs/catppuccin-sddm.nix { };
        ocf-papers = final.callPackage ./pkgs/ocf-papers.nix { };
        ocf-okular = final.kdePackages.callPackage ./pkgs/ocf-okular.nix { };
      };

      agenix-rekey = agenix-rekey.configure {
        userFlake = self;
        nixosConfigurations = self.colmenaHive.nodes;
      };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.agenix-rekey
            pkgs.age-plugin-fido2-hmac
            colmena.packages.${pkgs.system}.colmena
          ];
        };
        deploy = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.openssh
            colmena.packages.${pkgs.system}.colmena
          ];
        };
      });

      nixosConfigurations = builtins.mapAttrs
        (host: colmenaConfig: nixpkgs.lib.nixosSystem rec {
          system = overrideSystem.${host} or defaultSystem;
          pkgs = pkgsFor system;
          modules = colmenaConfig.imports;
          specialArgs = { inherit inputs; };
        })
        colmenaHosts;
    };
}
