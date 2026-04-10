{
  config,
  lib,
  ...
}:

let
  cfg = config.ocf.wetty;
in
{
  options.ocf.wetty = {
    enable = lib.mkEnableOption "Wetty web terminal service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "ssh.ocf.berkeley.edu";
      description = "Public hostname for the Wetty service";
    };
    sshHost = lib.mkOption {
      type = lib.types.str;
      default = "carp.ocf.berkeley.edu";
      description = "SSH host for Wetty to connect to";
    };
  };

  config = lib.mkIf cfg.enable {
    services.wetty = {
      enable = true;
      port = cfg.port;
      host = "127.0.0.1";
      sshHost = cfg.sshHost;
    };

    ocf.acme.extraCerts = [
      cfg.hostname
    ];

    users.users."nginx".extraGroups = [ "acme" ];

    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      virtualHosts = {
        "wetty" = {
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
          ];

          serverName = cfg.hostname;
          useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
          onlySSL = true;

          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
          };
        };

        "wetty-force-ssl" = {
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

          serverName = cfg.hostname;
          globalRedirect = "https://${cfg.hostname}";
        };
      };
    };
  };
}
