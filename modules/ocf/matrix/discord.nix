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
      settings = {
        bridge = {
          domain = cfg.serverName;
          homeserverUrl = cfg.baseUrl;
  
          enableSelfServiceBridging = true;
        };

        auth = {
          clientID = "1403658564685402203";
          # this is an anti-pattern, but i'm not sure there's an alternative
          botToken = builtins.readFile config.age.secrets.discord-bot-token.path;
          usePrivilegedIntents = true;
        };
      };
    };
  };
}
