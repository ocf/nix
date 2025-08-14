{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.matrix;
in
{
  options.ocf.matrix.irc-bridge = {
    enable = lib.mkEnableOption "Enable Matrix IRC bridge.";

    server = lib.mkOption {
      type = lib.types.str;
      description = "IRC server to bridge.";
      default = "irc.ocf.io";
    };

    initialRooms = lib.mkOption {
      type = lib.types.attrs;
      description = "Rooms to automatically bridge with IRC.";
      default = { };
    };
  };

  config = lib.mkIf cfg.irc-bridge.enable {
    services.matrix-appservice-irc = {
      enable = true;
      registrationUrl = "http://localhost:8010";
      port = 8010;

      settings = {

        homeserver = {
	  url = "https://${cfg.baseUrl}";
          domain = cfg.serverName;
	  enablePresence = true;
	};

        ircService.mediaProxy.publicUrl = "https://${cfg.baseUrl}/media";

        ircService.servers."${cfg.irc-bridge.server}" = {
          name = "OCF IRC";
          port = 6697;
          ssl = true;

          mappings = cfg.irc-bridge.initialRooms;

          matrixClients = {
            userTemplate = "@irc_$NICK";
          };

          ircClients = {
            nickTemplate = "$DISPLAY[m]";
            allowNickChanges = true;
          };

          botConfig = {
	    enabled = true;
	    nick = "MatrixBot";
	    username = "matrixbot";
	    joinChannelsIfNoUsers = true;
	  };

          dynamicChannels = {
	    enable = false;
	  };

          membershipLists = {
	    enabled = true;
	    global = {
	      ircToMatrix = {
	        initial = true;
	        incremental = true;
	      };
	      matrixToIrc = {
	        initial = true;
		incremental = true;
	      };
	    };
	    ignoreIdleUsersOnStartup.enabled = true;
	  };
        };
      };
    };

    services.nginx.virtualHosts."synapse".locations."/media".proxyPass = "http://[::1]:11111";

    services.matrix-synapse.settings.app_service_config_files = [
      "/etc/matrix-synapse/irc-registration.yaml"
    ];

    environment.etc = {
      "matrix-synapse/irc-registration.yaml" = {
        source = "/var/lib/matrix-appservice-irc/registration.yml";
        mode = "0440";
        user = "matrix-synapse";
        group = "matrix-synapse";
      };
    };
  };
}
