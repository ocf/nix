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
    services.nginx.virtualHosts = {
      "element-web" = {
        serverName = cfg.element.url;

        useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
        forceSSL = true;

        root = pkgs.element-web.override {
          conf = {
            default_server_config = {
              "m.homeserver".base_url = "https://${cfg.baseUrl}";
            };

            default_theme = "dark";
            brand = "OCF Chat";
          };
        };
      };

      "redirect" = {
        serverName = "*.ocf.berkeley.edu";
        globalRedirect = "${cfg.element.url}";

        useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
        forceSSL = true;
      };

      "synapse".locations."/".extraConfig = ''
        return 301 https://${cfg.element.url};
      '';
    };
  };
}
