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
  };

  config = lib.mkIf cfg.enable {
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
        ExecStart = "/bin/sh -c 'source /etc/profile && XDG_RUNTIME_DIR=/run/user/$(id -u) exec ${pkgs.ocf-jukebox}/bin/daphne -b 0.0.0.0 -p ${toString cfg.port} config.asgi:application'";
        User = "ocftv";
        StateDirectory = "jukebox";
        RuntimeDirectory = "jukebox-music";
        WorkingDirectory = "/var/lib/jukebox";
        Restart = "always";
      };
    };
  };
}
