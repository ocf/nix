{
  description = "NixOS configuration for the Open Computing Facility";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-deprecated.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default/main";

    colmena = {
      url = "github:zhaofengli/colmena/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix-rekey = {
      url = "github:oddlama/agenix-rekey/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niks3 = {
      url = "github:Mic92/niks3/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # -- OCF Inputs -- #

    ocflib.url = "github:ocf/ocflib/master";
    ocf-sync-etc.url = "github:ocf/etc/master";
    ocf-pam-trimspaces.url = "github:ocf/pam_trimspaces/master";

    ocf-utils = {
      url = "github:ocf/utils/master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ocflib.follows = "ocflib";
    };

    wayout = {
      url = "github:ocf/wayout/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ocf-cosmic-applets = {
      url = "github:ocf/cosmic-applets/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ocf-jukebox = {
      url = "github:ocf/jukebox-django";
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

      hostDefaults = {
        inherit nixpkgs;
        system = "x86_64-linux";
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

      # override the hostDefaults attribute set per host
      #
      # NOTE: all hosts will be sharing the same ocf nix modules in this
      # repository regardless of what pkgs or system is set to
      hostOverrides = {
        overheat.system = "aarch64-linux";
      };

      # ============== #
      # Glue/Internals #
      # ============== #

      # returns the nixpkgs pkgs set for a given:
      # - nixpkgs input
      # - system architecture like "x86_64-linux"
      pkgsFor =
        {
          nixpkgs,
          system,
          config,
          ...
        }@args:
        import args.nixpkgs {
          inherit overlays;
          inherit (args) system config;
        };

      specialArgsFor =
        hostAttrs:
        let
          pkgsFromInput = nixpkgs': pkgsFor (hostAttrs // { nixpkgs = nixpkgs'; });
        in
        {
          inherit self inputs;

          # even if stable is the default, an overridden host may still want to
          # access pkgs-stable as a specialArg
          pkgs-stable = pkgsFromInput nixpkgs;

          # pkgs-unstable exposes the packages from the nixpkgs-unstable input
          # this should only be used as a *temporary* measure when the version of
          # a package in nixpkgs stable is not sufficiently updated
          pkgs-unstable = pkgsFromInput nixpkgs-unstable;
          pkgs-deprecated = pkgsFromInput nixpkgs-deprecated;
        };

      mapHostOverrides =
        f: builtins.mapAttrs (name: overrides: f (hostDefaults // overrides)) hostOverrides;

      forAllSystems =
        fn:
        nixpkgs.lib.genAttrs (import systems) (system: fn (pkgsFor (hostDefaults // { inherit system; })));

      readGroup =
        group:
        let
          groupDir = builtins.readDir ./hosts/${group};
          # exclude files directories in hosts/group/* that end with .disabled
          activeHosts = nixpkgs.lib.filterAttrs (
            name: value: !(nixpkgs.lib.hasSuffix ".disabled" name)
          ) groupDir;
        in
        nixpkgs.lib.mapAttrs' (host: _: {
          # host config in hosts/group/* can be in the form of hostname.nix or
          # hostname (directory containing default.nix)
          # FIXME: colmenaHosts expects a .nix file so this doesnt actually
          # work even though readGroup technically supports it
          name = nixpkgs.lib.removeSuffix ".nix" host;
          value = group;
        }) activeHosts;

      hosts = nixpkgs.lib.concatMapAttrs (group: _: readGroup group) (builtins.readDir ./hosts);

      deploy-user = "ocf-nix-deploy-user";
      colmenaHosts = builtins.mapAttrs (
        host: group:
        let
          profile = builtins.filter builtins.pathExists [ ./profiles/${group}.nix ];
          hostConfig = ./hosts/${group}/${host}.nix;
        in
        { config, ... }: {
          imports = nixpkgs.lib.flatten [
            commonModules
            profile
            hostConfig
          ];

          deployment.tags = [ group ];
          deployment.targetHost = "${host}.ocf.berkeley.edu";
          # TODO: Think of a less ugly way of doing this
          deployment.targetUser =
            nixpkgs.lib.mkIf self.colmenaHive.nodes.${host}.config.ocf.managed-deployment.enable
              deploy-user;

          system.nixos.variant_id = "ocf-${group}";
          system.nixos.variantName = config.system.nixos.variant_id;

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
            nixpkgs = pkgsFor hostDefaults;
            nodeNixpkgs = mapHostOverrides pkgsFor;
            specialArgs = specialArgsFor hostDefaults;
            nodeSpecialArgs = mapHostOverrides specialArgsFor;
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

        # nixpkgs quota is built without RPC support, it can't query
        # NFS quotas from the filehost via rquotad.
        # This wasn't necessary for old puppet hosts because debian packages quota with rpc enabled.
        quota = prev.quota.overrideAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ final.libtirpc ];
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.rpcsvc-proto ];
          configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-rpc" ];
        });
      };

      agenix-rekey = agenix-rekey.configure {
        userFlake = self;
        nixosConfigurations = self.colmenaHive.nodes;
      };

      devShells = forAllSystems (
        pkgs:
        let
          # explicitly use pkgs so it doesnt collide with flake inputs
          deployPkgs = [
            colmena.packages.${pkgs.stdenv.hostPlatform.system}.colmena
            pkgs.git
            pkgs.openssh_gssapi
            pkgs.wol
            pkgs.nixfmt-tree
            pkgs.nix-fast-build
          ];
        in
        {
          # for development/debugging
          default = pkgs.mkShell {
            packages =
              # explicitly use pkgs so it doesnt collide with flake inputs
              [
                disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
                pkgs.age
                pkgs.agenix-rekey
                pkgs.age-plugin-fido2-hmac
                pkgs.nix-du
                pkgs.nix-tree
                pkgs.nix-eval-jobs
                pkgs.nix-output-monitor
              ]
              ++ deployPkgs;

            shellHook = ''
              export AGENIX_REKEY_PRIMARY_IDENTITY="$(grep -Poe "^# public key(?: \(pq safe\))?: \K.*$" secrets/master-identities/by-username/$(whoami) | head -1)"
            '';
          };

          # for ci/cd
          deploy = pkgs.mkShell {
            packages = deployPkgs;
          };
        }
      );

      nixosConfigurations = self.colmenaHive.nodes;
    };
}
