{ pkgs, lib, config, ... }:

let 
  cfg = config.ocf.matrix;
in
{
  options.ocf.matrix = {
    enable = lib.mkEnableOption "Enable Matrix server";
    
    postgresPackage = lib.mkOption {
      type = lib.types.package;
      description = "PostgreSQL package version, incremented only after manual upgrade.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      description = "Matrix base URL.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      description = "Matrix server name.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.synapse-client-secret.rekeyFile = ../../../secrets/master-keyed/matrix/client-secret.age;
    age.secrets.synapse-client-secret.owner = "matrix-synapse";

    services.postgresql = {
      enable = true;
      package = cfg.postgresPackage;

      # this feels hacky but i don't know a better way to do it
      initialScript = pkgs.writeText "init-sql-script" ''
        create user "matrix-synapse";
        create database "matrix-synapse" with owner "matrix-synapse"
          template template0
          lc_collate = "C"
          lc_ctype = "C";
      '';
    };

    services.matrix-synapse = {
      enable = true;

      settings = {
        password_config.enabled = false;

        auto_join_rooms = [
          "#rebuild:ocf.io"
          "#decal-general:ocf.io"
        ];

        oidc_providers = [
          {
            idp_id = "keycloak";
            idp_name = "OCF";
            issuer = "https://idm.ocf.berkeley.edu/realms/ocf";
            client_id = "matrix";
            client_secret_path = config.age.secrets.synapse-client-secret.path;
            scopes = [ "openid" "profile" ];
            user_mapping_provider = {
              config = {
                localpart_template = "{{ user.preferred_username }}";
                display_name_template = "{{ user.name }}"; 
              };
            };
          }
        ];

        server_name = cfg.serverName;
        public_baseurl = "https://${cfg.baseUrl}";

        listeners = [
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
    };
# TODO(@laksith19): Expose adding users to acme group as a part of the ocf.amce module. And expose reloading acme dependent services using security.acme.defaults.reloadServices = []; (not important here as Nginx options in Nix handle that for us, but should be easily accessed from the ocf.acme module)
    users.users."nginx".extraGroups = [ "acme" ];

    services.nginx = {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      

      virtualHosts = {
        "synapse" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 443;
              ssl = true;
            }
            {
              addr = "[::0]";
              port = 443;
              ssl = true;
            }
            {
              addr = "0.0.0.0";
              port = 8448;
              ssl = true;
            }
            {
              addr = "[::0]";
              port = 8448;
              ssl = true;
            }
          ];

          serverName = cfg.baseUrl;

          useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
          onlySSL = true;

          locations."/".extraConfig = ''
            return 404;
          '';

          locations."/_matrix".proxyPass = "http://[::1]:8008";

          locations."/_synapse/client".proxyPass = "http://[::1]:8008";
        };

        "force-ssl" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 80;
            }
            {
              addr = "[::0]";
              port = 80;
            }
          ];

          serverName = cfg.baseUrl;
          globalRedirect = "https://${cfg.baseUrl}";
        };
      };
    };
  };
}
