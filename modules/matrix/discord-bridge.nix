{
  pkgs,
  lib,
  config,
  pkgs-deprecated,
  ...
}:

let
  cfg = config.ocf.matrix;
in
{
  options.ocf.matrix.discord-bridge = {
    enable = lib.mkEnableOption "Enable Matrix Discord bridge.";
  };

  config = lib.mkIf cfg.discord-bridge.enable {
    age.secrets.discord-auth-env.rekeyFile = ../../secrets/master-keyed/matrix/discord-auth-env.age;

    services.matrix-appservice-discord = {
      enable = true;

      # even after adding:
      # nixpkgs.config.permittedInsecurePackages = [
      #   "nodejs-20.20.2"
      #   "nodejs-slim-20.20.2"
      #   "nodejs-20.20.2-source"
      # ];
      #
      # to ./modules/matrix/discord-bridge.nix, scootaloo still fails to
      # build with:
      # "error: attribute 'nodeAppDir' missing"
      #
      # we will pull matrix-appservice-discord from pkgs-deprecated (25.11)
      # for now until matrix-appservice-discord is updated.
      #
      # see: https://github.com/NixOS/nixpkgs/issues/515284
      package = pkgs-deprecated.matrix-appservice-discord;

      environmentFile = config.age.secrets.discord-auth-env.path;

      settings = {
        channel.namePattern = ":name";

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
