{
  lib,
  config,
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

    services.niks3 = {
      enable = true;
      httpAddr = "127.0.0.1:5751";

      s3 = {
        endpoint = "o3.ocf.berkeley.edu";
        bucket = "ocf-niks3";
        useSSL = true;
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

    ocf.acme.extraCerts = [ cfg.cacheDomain ];
    users.users."nginx".extraGroups = [ "acme" ];

    services.nginx.virtualHosts.${cfg.cacheDomain} = {
      useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
    };

    systemd.services.niks3.serviceConfig = {
      MemoryHigh = "4G";
      MemoryMax = "6G";
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
