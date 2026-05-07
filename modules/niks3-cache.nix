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
      description = "Path to file containing the RustFS S3 access key.";
    };

    s3SecretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the RustFS S3 secret key.";
    };

    pushGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "User groups allowed to push to the cache.";
      default = [ "ocfstaff" ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.rustfs = {
      enable = true;
      accessKeyFile = cfg.s3AccessKeyFile;
      secretKeyFile = cfg.s3SecretKeyFile;
      address = ":9000";
      consoleAddress = ":9001";
      volumes = [ "/var/lib/rustfs" ];
    };

    # Create bucket and set anonymous read on first boot
    systemd.services.rustfs-setup = {
      description = "RustFS bucket setup for niks3";
      after = [ "rustfs.service" ];
      requires = [ "rustfs.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment.HOME = "/tmp/mc-home";
      path = [ pkgs.minio-client ];
      script = ''
        set -euo pipefail

        ACCESS_KEY=$(cat "${cfg.s3AccessKeyFile}")
        SECRET_KEY=$(cat "${cfg.s3SecretKeyFile}")

        # Create bucket (fails harmlessly if already exists)
        mc mb local/ocf-niks3 || echo "bucket create: already exists"

        # Enable anonymous read access
        mc anonymous set download local/ocf-niks3
      '';
    };

    services.niks3 = {
      enable = true;
      httpAddr = "127.0.0.1:5751";

      s3 = {
        endpoint = "${config.networking.hostName}.ocf.berkeley.edu:9000";
        bucket = "ocf-niks3";
        region = "us-east-1";
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

      readProxy.enable = false;

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

    systemd.services.niks3 = {
      after = [ "rustfs-setup.service" ];
      requires = [ "rustfs-setup.service" ];
    };

    ocf.acme.extraCerts = [ cfg.cacheDomain ];
    users.users."nginx".extraGroups = [ "acme" ];

    # Reads go directly to RustFS (anonymous), push API goes to niks3
    services.nginx.virtualHosts.${cfg.cacheDomain} = {
      useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
      locations."/" = {
        proxyPass = lib.mkForce "http://127.0.0.1:9000/ocf-niks3/";
      };
      locations."/api" = {
        proxyPass = "http://127.0.0.1:5751/api";
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
      9000
    ];
  };
}
