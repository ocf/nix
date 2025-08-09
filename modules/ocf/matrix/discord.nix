{ pkgs, lib, config, ... }:

let 
  cfg = config.ocf.matrix;
in
{
  options.ocf.matrix.discord = {
    enable = lib.mkEnableOption "Enable Matrix Discord bridge.";
  };

  config = lib.mkIf cfg.discord.enable {
    age.secrets.discord-auth-env.rekeyFile = ../../../secrets/master-keyed/matrix/discord-auth-env.age;

    services.matrix-appservice-discord = {
      enable = true;

      environmentFile = config.age.secrets.discord-auth-env.path;

      settings = {
        bridge = {
          domain = cfg.serverName;
          homeserverUrl = "https://${cfg.baseUrl}";
  
          enableSelfServiceBridging = true;
          disableJoinLeaveNotifications = true;
          disableInviteNotifications = true;
        };
      };
    };

    services.matrix-synapse.settings.app_service_config_files = [
      "/etc/matrix-synapse/discord-registration.yaml"
    ];

    environment.etc = { 
      "matrix-synapse/discord-registration.yaml" = { 
        source = "/var/lib/matrix-appservice-discord/discord-registration.yaml";
        mode = "0440";
        user = "matrix-synapse";
        group = "matrix-synapse";
      };
    };
  };
}
