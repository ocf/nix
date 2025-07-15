{
  description = "NixOS desktop configuration for the Open Computing Facility";

inputs = {
  nixpkgs = {
    type = "github";
    owner = "nixos";
    repo = "nixpkgs";
    ref  = "nixos-unstable";
  };

  systems = {
    type = "github";
    owner = "nix-systems";
    repo = "default";
    ref  = "main";
  };

  colmena = {
    type = "github";
    owner = "zhaofengli";
    repo = "colmena";
    ref  = "main";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  "nix-index-database" = {
    type = "github";
    owner = "nix-community";
    repo = "nix-index-database";
    ref  = "main";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  ocflib = {
    type = "github";
    owner = "ocf";
    repo = "ocflib";
    ref  = "master";
  };

  "ocf-sync-etc" = {
    type = "github";
    owner = "ocf";
    repo = "etc";
    ref  = "master";
  };

  "ocf-pam-trimspaces" = {
    type = "github";
    owner = "ocf";
    repo = "pam_trimspaces";
    ref  = "master";
  };

  "ocf-utils" = {
    type = "github";
    owner = "ocf";
    repo = "utils";
    ref  = "master";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  wayout = {
    type = "github";
    owner = "ocf";
    repo = "wayout";
    ref  = "main";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

  outputs =
    { self
    , nixpkgs
    , systems
    , colmena
    , nix-index-database
    , ocflib
    , ocf-sync-etc
    , ocf-pam-trimspaces
    , ocf-utils
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
      ];

      commonModules = with nixpkgs.lib; [
        ./profiles/base.nix
      ] ++ filter (hasSuffix ".nix") (filesystem.listFilesRecursive ./modules);

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

      colmenaHosts = builtins.mapAttrs
        (host: { modules, group }: {
          imports = commonModules ++ modules;
          deployment.tags = [ group ];
          deployment.targetHost = "${host}.ocf.berkeley.edu";
          deployment.targetUser = "root";
          deployment.allowLocalDeployment = true;
        })
        hosts;
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);

      colmenaHive = colmena.lib.makeHive self.outputs.colmena;

      colmena = colmenaHosts // {
        meta = {
          nixpkgs = pkgsFor defaultSystem;
          nodeNixpkgs = nixpkgs.lib.mapAttrs (name: pkgsFor) overrideSystem;
          specialArgs = { inherit inputs; };
        };
      };

      packages = forAllSystems (pkgs: {
        bootstrap = pkgs.callPackage ./bootstrap { };
      });

      overlays.default = final: prev: {
        ocf-utils = ocf-utils.packages.${final.system}.default;
        ocf-wayout = wayout.packages.${final.system}.default;
        plasma-applet-commandoutput = final.callPackage ./pkgs/plasma-applet-commandoutput.nix { };
        catppuccin-sddm = final.qt6Packages.callPackage ./pkgs/catppuccin-sddm.nix { };
        ocf-papers = final.callPackage ./pkgs/ocf-papers.nix { };
        ocf-okular = final.kdePackages.callPackage ./pkgs/ocf-okular.nix { };
      };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.git
            colmena.packages.${pkgs.system}.colmena
          ];
        };
      });

      # We usually deploy hosts with colmena, but bootstrap currently uses the
      # nixosConfigurations flake output... this isn't exactly the same, because
      # colmena adds a couple of things to it, but it's OK for now...

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
