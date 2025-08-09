{ pkgs, lib, config, ... }:

let 
  cfg = config.ocf.matrix;
in
{
  options.ocf.matrix.discord = {
    enable = lib.mkEnableOption "Enable Matrix Discord bridge.";
    
    baseUrl = lib.mkOption {
      type = lib.types.str;
      description = "Synapse base URL.";
    };

    serverName = lib.mkOption {
      type = lib.types.str;
      description = "Synapse server name.";
    };
  };

  config = lib.mkIf cfg.discord.enable {
    age.secrets.discord-bot-token.rekeyFile = ../../secrets/master-keyed/matrix/bot-token.age;

    services.matrix-appservice-discord = {
      environmentFile = config.age.secrets.discord-bot-token.path;

      settings = {
        bridge = {
          domain = cfg.serverName;
          homeserverUrl = cfg.baseUrl;
  
          enableSelfServiceBridging = true;
        };
      };
    };
  };
}
