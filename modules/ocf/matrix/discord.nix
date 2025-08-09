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
          homeserverUrl = cfg.baseUrl;
  
          enableSelfServiceBridging = true;
        };
      };
    };

    services.matrix-synapse.settings.app_service_config_files = [
      "/var/lib/matrix-synapse/discord-registration.yaml"
    ];

    # this feels like a hack
    systemd.services.matrix-appservice-discord.postStart = lib.mkAfter ''
      cp /var/lib/matrix-appservice-discord/discord-registration.yaml /var/lib/matrix-synapse/
      chown matrix-synapse:matrix-synapse /var/lib/matrix-synapse/discord-registration.yaml
    '';
  };
}
