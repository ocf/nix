{ config, lib, pkgs, ... }:

let
  cfg = config.ocf.jukebox;
in
{
  options.ocf.jukebox = {
    enable = lib.mkEnableOption "OCF Jukebox service";
    secretKey = lib.mkOption {
      type = lib.types.str;
      default = "tmp-key";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8001;
    };
    musicDir = lib.mkOption {
      type = lib.types.path;
      default = "/run/jukebox-music";
    };

    jukeboxUrl = lib.mkOption {
      type = lib.types.str;
      description = "Jukebox URL";
      default = "jukebox.ocf.io";
    };
  };

  config = lib.mkIf cfg.enable {

    ocf.acme.extraCerts = [ "jukebox.ocf.berkeley.edu" "jukebox.ocf.io" ];

    users.users."nginx".extraGroups = [ "acme" ];

    systemd.services.jukebox = {
      description = "OCF Jukebox Django Server";
      after = [ "network.target" "nss-lookup.target" ];
      wants = [ "nss-lookup.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        JUKEBOX_MUSIC_DIR = cfg.musicDir;
        SECRET_KEY = cfg.secretKey;
        DJANGO_DB_PATH = "/var/lib/jukebox/db.sqlite3";
      };
      serviceConfig = {
        ExecStart = "/bin/sh -c 'source /etc/profile && XDG_RUNTIME_DIR=/run/user/$(id -u) exec ${pkgs.ocf-jukebox}/bin/daphne -b localhost -p ${toString cfg.port} config.asgi:application'";
        User = "ocftv";
        StateDirectory = "jukebox";
        RuntimeDirectory = "jukebox-music";
        WorkingDirectory = "/var/lib/jukebox";
        Restart = "always";
      };
    };

    services.nginx = {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;


      virtualHosts = {
        "jukebox" = {
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

          serverName = cfg.jukeboxUrl;

          useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
          onlySSL = true;

          locations."/" = { 
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            proxyWebsockets = true;
          };
          
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

          serverName = cfg.jukeboxUrl;
          globalRedirect = "https://${cfg.jukeboxUrl}";
        };
      };
    };
  };
}
