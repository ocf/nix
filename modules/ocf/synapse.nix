{ pkgs, lib, config, ... }:

let 
  cfg = config.ocf.synapse;
in
{
  options.ocf.synapse = {
    enable = lib.mkEnableOption "Enable Synapse";
    
    postgresPackage = lib.mkOption {
      type = lib.types.package;
      description = "PostgreSQL package version, incremented only after manual upgrade.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      description = "Synapse base URL.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      description = "Synapse server name.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.synapse-postgres-passwd.rekeyFile = ../../secrets/master-keyed/synapse-postgres-passwd.age;

    services.postgresql = {
      enable = true;
      package = cfg.postgresPackage;

      ensureUsers = [
        {
          name = "matrix-synapse";
        }
      ];

      initialScript = pkgs.writeText "init-sql-script" ''
        create database "matrix-synapse" with owner "matrix-synapse"
          template template0
          lc_collate = "C"
          lc_ctype = "C";
        alter user matrix-synapse with password '$(cat "${config.age.secrets.synapse-postgres-passwd.path}")';
      '';
    };

    services.matrix-synapse = {
      enable = true;
      settings.server_name = cfg.serverName;
      settings.public_baseurl = "https://${cfg.baseUrl}";

      settings.listeners = [
        {
          port = 8008;
          bind_addresses = [ "::1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [
                "client"
                "federation"
              ];
              compress = true;
            }
          ];
        }
      ];
    };

    users.users."nginx".extraGroups = [ "acme" ];

    services.nginx = {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      

      virtualHosts = {
        "${cfg.baseUrl}" = {
          useACMEHost = "${config.networking.hostName}.${cfg.serverName}";
          forceSSL = true;

          locations."/".extraConfig = ''
            return 404;
          '';

          locations."/_matrix".proxyPass = "http://[::1]:8008";

          locations."/_synapse/client".proxyPass = "http://[::1]:8008";
        };
      };
    };
  };
}
