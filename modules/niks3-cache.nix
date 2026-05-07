{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.niks3-cache;
  keycloakIssuer = "https://idm.ocf.berkeley.edu/realms/ocf";
in
{
  options.ocf.niks3-cache = {
    enable = lib.mkEnableOption "OCF niks3 binary cache";

    cacheDomain = lib.mkOption {
      type = lib.types.str;
      description = "Public domain for the binary cache (used for nginx, ACME, and cacheUrl).";
      default = "cache.ocf.berkeley.edu";
    };

    apiTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the niks3 API token.";
    };

    signingKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the NAR signing key.";
    };

    s3AccessKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Garage S3 access key ID (starts with GK).";
    };

    s3SecretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Garage S3 secret key.";
    };

    pushGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "User groups allowed to push to the cache.";
      default = [ "ocfstaff" ];
    };
  };

  config = lib.mkIf cfg.enable {

    # -- Garage: local S3 backend --

    age.secrets.garage-env = {
      rekeyFile = ../secrets/master-keyed/niks3-cache/garage-env.age;
    };

    services.garage = {
      enable = true;
      package = pkgs.garage;
      environmentFile = config.age.secrets.garage-env.path;
      settings = {
        metadata_dir = "/var/lib/garage/meta";
        data_dir = "/var/lib/garage/data";
        replication_mode = "none";
        rpc_bind_addr = "[::]:3901";
        rpc_public_addr = "127.0.0.1:3901";
        s3_api = {
          s3_region = "garage";
          api_bind_addr = "[::]:3900";
          root_domain = ".s3.garage";
        };
      };
    };

    systemd.services.garage-setup = {
      description = "Garage S3 initial setup for niks3";
      after = [ "garage.service" ];
      requires = [ "garage.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = config.age.secrets.garage-env.path;
      };
      path = [ config.services.garage.package ];
      script = ''
        set -euo pipefail

        # Wait for Garage RPC to be ready
        for i in $(seq 1 30); do
          garage status >/dev/null 2>&1 && break
          sleep 1
        done

        # Assign node to layout (fails harmlessly if already assigned)
        NODE_ID=$(garage node id -q | cut -c1-16)
        garage layout assign -z dc1 -c 1T "$NODE_ID" || echo "layout assign: already assigned"
        garage layout apply --version 1 || echo "layout apply: already applied"

        # Wait for layout to be active
        for i in $(seq 1 30); do
          garage bucket list >/dev/null 2>&1 && break
          sleep 1
        done

        # Import S3 key from agenix (fails harmlessly if already exists)
        ACCESS_KEY=$(cat "${cfg.s3AccessKeyFile}")
        SECRET_KEY=$(cat "${cfg.s3SecretKeyFile}")
        garage key import --yes -n niks3 "$ACCESS_KEY" "$SECRET_KEY" || echo "key import: already exists"

        # Create bucket and grant access (fails harmlessly if already done)
        garage bucket create ocf-niks3 || echo "bucket create: already exists"
        garage bucket allow --read --write --owner ocf-niks3 --key niks3
      '';
    };

    # -- niks3: binary cache server --

    services.niks3 = {
      enable = true;
      httpAddr = "127.0.0.1:5751";

      s3 = {
        endpoint = "${config.networking.hostName}.ocf.berkeley.edu:3900";
        bucket = "ocf-niks3";
        region = "garage";
        useSSL = false;
        accessKeyFile = cfg.s3AccessKeyFile;
        secretKeyFile = cfg.s3SecretKeyFile;
      };

      apiTokenFile = cfg.apiTokenFile;
      signKeyFiles = [ cfg.signingKeyFile ];
      cacheUrl = "https://${cfg.cacheDomain}";

      oidc.providers = {
        ocf = {
          issuer = keycloakIssuer;
          audience = "niks3";
          boundClaims = {
            groups = cfg.pushGroups;
          };
        };
      };

      readProxy.enable = true;

      nginx = {
        enable = true;
        domain = cfg.cacheDomain;
        enableACME = false;
        forceSSL = true;
      };

      gc = {
        enable = true;
        olderThan = "2160h";
        failedUploadsOlderThan = "12h";
        schedule = "Sun *-*-* 03:00:00";
        randomizedDelaySec = 1800;
      };
    };

    # niks3 must wait for Garage setup to complete
    systemd.services.niks3 = {
      after = [ "garage-setup.service" ];
      requires = [ "garage-setup.service" ];
    };

    ocf.acme.extraCerts = [ cfg.cacheDomain ];
    users.users."nginx".extraGroups = [ "acme" ];

    services.nginx.virtualHosts.${cfg.cacheDomain} = {
      useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
      locations."/".extraConfig = ''
        proxy_cache_valid 200 24h;
        proxy_cache_valid 404 5m;
      '';
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
      3900
    ];
  };
}
