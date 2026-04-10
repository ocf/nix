{
  config,
  lib,
  ...
}:

let
  cfg = config.ocf.ttyd;
  hostnameIo = lib.strings.replaceStrings [ "ocf.berkeley.edu" ] [ "ocf.io" ] cfg.hostname;
in
{
  options.ocf.ttyd = {
    enable = lib.mkEnableOption "ttyd web terminal service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "ssh.ocf.berkeley.edu";
      description = "Public hostname for the ttyd service";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ttyd = {
      enable = true;
      port = cfg.port;
      interface = "127.0.0.1";
      writeable = true;
    };

    ocf.acme.extraCerts = [
      cfg.hostname
      hostnameIo
    ];

    users.users."nginx".extraGroups = [ "acme" ];

    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      virtualHosts = {
        "ttyd" = {
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
          serverAliases = [ hostnameIo ];
          useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
          onlySSL = true;

          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
          };
        };

        "ttyd-force-ssl" = {
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
          serverAliases = [ hostnameIo ];
          globalRedirect = "https://${cfg.hostname}";
        };
      };
    };
  };
}
