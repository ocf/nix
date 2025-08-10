{ pkgs, lib, config, ... }:

let 
  cfg = config.ocf.matrix;
in
{
  options.ocf.matrix.element = {
    enable = lib.mkEnableOption "Enable Element web client.";

    
    url = lib.mkOption {
      type = lib.types.str;
      description = "Element URL.";
    };
  };

  config = lib.mkIf cfg.discord.enable {
    services.nginx.virtualHosts."element-web" = {
      serverName = cfg.element.url;

      useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
      forceSSL = true;
      serverAliases = [ "element.${config.networking.domain}" ];

      root = pkgs.element-web.override {
        conf = {
          default_server_name = cfg.serverName;
        };
      };
    };
  };
}
