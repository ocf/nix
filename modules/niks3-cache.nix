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
      description = "Path to file containing the S3 access key.";
    };

    s3SecretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the S3 secret key.";
    };

    pushGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "User groups allowed to push to the cache.";
      default = [ "ocfstaff" ];
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.seaweedfs = {
      description = "SeaweedFS server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        StateDirectory = "seaweedfs";
        DynamicUser = true;
        Restart = "on-failure";
        LoadCredential = [
          "s3-access-key:${cfg.s3AccessKeyFile}"
          "s3-secret-key:${cfg.s3SecretKeyFile}"
        ];
      };
      script = ''
        ACCESS_KEY=$(cat "$CREDENTIALS_DIRECTORY/s3-access-key")
        SECRET_KEY=$(cat "$CREDENTIALS_DIRECTORY/s3-secret-key")

        cat > /var/lib/seaweedfs/s3.json <<EOF
        {
          "defaultEffect": "Deny",
          "identities": [
            {
              "name": "niks3",
              "credentials": [{"accessKey": "$ACCESS_KEY", "secretKey": "$SECRET_KEY"}],
              "actions": ["Admin", "Read", "Write", "List", "Tagging"]
            },
            {
              "name": "anonymous",
              "actions": ["Read", "List"]
            }
          ]
        }
        EOF

        exec ${pkgs.seaweedfs}/bin/weed server \
          -dir=/var/lib/seaweedfs \
          -s3 -filer \
          -ip=${config.networking.hostName}.ocf.berkeley.edu \
          -ip.bind=:: \
          -s3.port=8333 \
          -volume.max=300 \
          -s3.config=/var/lib/seaweedfs/s3.json
      '';
    };

    services.niks3 = {
      enable = true;
      httpAddr = "127.0.0.1:5751";

      s3 = {
        endpoint = "${config.networking.hostName}.ocf.berkeley.edu:8333";
        bucket = "ocf-niks3";
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
        olderThan = "2160h"; # 90 days
        failedUploadsOlderThan = "12h";
        schedule = "Sun *-*-* 03:00:00";
        randomizedDelaySec = 1800;
      };
    };

    systemd.services.niks3 = {
      after = [ "seaweedfs.service" ];
      requires = [ "seaweedfs.service" ];
    };

    ocf.acme.extraCerts = [ cfg.cacheDomain ];
    users.users."nginx".extraGroups = [ "acme" ];

    # Reads go directly to SeaweedFS S3 (anonymous), push API goes to niks3
    services.nginx.virtualHosts.${cfg.cacheDomain} = {
      useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
      locations."/" = {
        proxyPass = lib.mkForce "http://127.0.0.1:8333/ocf-niks3/";
      };
      locations."/api" = {
        proxyPass = "http://127.0.0.1:5751/api";
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
      8333
    ];
  };
}
