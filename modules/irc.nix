{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.irc;
in
{
  options.ocf.irc = {
    enable = lib.mkEnableOption "Enable IRC Server";

    oauth2 = {
      enable = lib.mkEnableOption "Enable OAuth2/OIDC authentication via Keycloak";

      issuer = lib.mkOption {
        type = lib.types.str;
        description = "Keycloak realm issuer URL";
        default = "https://idm.ocf.berkeley.edu/realms/ocf";
      };

      clientId = lib.mkOption {
        type = lib.types.str;
        description = "OAuth2 client ID registered in Keycloak";
        default = "ergo";
      };

      autocreate = lib.mkOption {
        type = lib.types.bool;
        description = "Automatically create IRC accounts on successful OAuth2 authentication";
        default = true;
      };
    };

    motd = lib.mkOption {
      type = lib.types.str;
      description = "Message of the Day";
      default = ''
                - Welcome! -

        	This is the server for official (TM) Open Computing Facility (OCF)
        	business. It's connected to the rest of the OCF Chat Network (Element,
        	Slack, and Discord). Please use your OCF username as your nickname if
        	you have one, although this isn't strictly required.

        	- The Golden Rule -

        	All users of OCF managed facilities (including this server) shall
        	comply with University of California regulations, including the UC
        	Berkeley Student Conduct Code and any OCF regulations. The OCF reserves
        	the right to deny services to any user who fails to follow any such
        	regulations.

                - Getting Involved -

        	The OCF is different from many clubs at Berkeley: we have no
        	application process or other requirements to join for any student! All
        	you need to get involved on staff is to start talking to people. We
        	hold socials frequently, and you're always welcome to read #off-topic
        	social discussion, or #rebuild and #administrivia for technical and
        	organizational discussion.

        	We understand that not having structure is a little strange, so here's
        	my advice: start reading #rebuild and #administrivia and hop into a
        	conversation. If you'd like, you can mention that you're new so people
        	won't assume you have organizational context. Sending a short message
        	for us in #introduce-yourself also helps, especially if you're not a
        	current Berkeley student.

        	If you'd prefer to start with more guidance, show up to our staff
        	meetings in person (our most up-to-date meeting time will be listed at
        	https://www.ocf.berkeley.edu/about/staff).

      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.irc-passwd.rekeyFile = ../secrets/master-keyed/irc-passwd.age;
    age.secrets.irc-oauth2-secret = lib.mkIf cfg.oauth2.enable {
      rekeyFile = ../secrets/master-keyed/irc/oauth2-client-secret.age;
    };

    security.acme.defaults.reloadServices = [ "ergochat.service" ];

    system.activationScripts."irc-secrets" = ''
      configFile=/etc/ergo.yaml

      # Substitute oper password
      secret=$(cat "${config.age.secrets.irc-passwd.path}")
      ${lib.getExe pkgs.gnused} -i "s/@irc-passwd@/$secret/g" "$configFile"

      ${lib.optionalString cfg.oauth2.enable ''
        # Substitute OAuth2 client secret
        oauth2Secret=$(cat "${config.age.secrets.irc-oauth2-secret.path}")
        ${lib.getExe pkgs.gnused} -i "s/@irc-oauth2-secret@/$oauth2Secret/g" "$configFile"
      ''}
    '';

    services.ergochat = {
      enable = true;
      settings = {
        channels = {
          operator-only-creation = true;
          auto-join = [
            "#announcements"
            "#introduce-yourself"
            "#rebuild"
            "#off-topic"
            "#board-games"
            "#hack-day"
            "#decal"
            "#administrivia"
            "#opstaff"
            "#design"
          ];
        };
        oper-classes = {
          "server-admin" = {
            title = "Server Admin";
            "capabilities" = [
              "kill" # disconnect user sessions
              "ban" # ban IPs, CIDRs, NUH masks, and suspend accounts (UBAN / DLINE / KLINE)
              "nofakelag" # exempted from fakelag restrictions on rate of message sending
              "relaymsg" # use RELAYMSG in any channel (see the `relaymsg` config block)
              "vhosts" # add and remove vhosts from users
              "sajoin" # join arbitrary channels, including private channels
              "samode" # modify arbitrary channel and user modes
              "snomasks" # subscribe to arbitrary server notice masks
              "roleplay" # use the (deprecated) roleplay commands in any channel
              "rehash" # rehash the server, i.e. reload the config at runtime
              "accreg" # modify arbitrary account registrations
              "chanreg" # modify arbitrary channel registrations
              "history" # modify or delete history messages
              "defcon" # use the DEFCON command (restrict server capabilities)
              "massmessage" # message all users on the server
              "metadata" # modify arbitrary metadata on channels and users
            ];
          };
        };
        opers = {
          admin = {
            class = "server-admin";
            password = "@irc-passwd@";
          };
        };
        network.name = "OCF";
        server = {
          name = "irc.ocf.berkeley.edu";
          motd = pkgs.writeText "ircd.motd" cfg.motd;
          sts.enabled = true;
          listeners.":6697".tls = {
            cert = "/var/lib/acme/scootaloo.ocf.berkeley.edu/fullchain.pem";
            key = "/var/lib/acme/scootaloo.ocf.berkeley.edu/key.pem";
          };
        };

        # OAuth2 authentication via Keycloak
        oauth2 = lib.mkIf cfg.oauth2.enable {
          enabled = true;
          autocreate = cfg.oauth2.autocreate;
          introspection-url = "${cfg.oauth2.issuer}/protocol/openid-connect/token/introspect";
          introspection-timeout = "10s";
          client-id = cfg.oauth2.clientId;
          client-secret = "@irc-oauth2-secret@";
        };

        # Account settings for OAuth2
        accounts = lib.mkIf cfg.oauth2.enable {
          authentication-enabled = true;
          registration.enabled = false; # Users authenticate via Keycloak, not local registration
          require-sasl.enabled = false; # Allow unauthenticated connections

          nick-reservation = {
            enabled = true;
            # "strict" = unregistered users cannot use registered nicks
            # "optional" = registered nicks are protected but not required
            method = "strict";
            # Force authenticated users to use their account name as nick
            force-nick-equals-account = true;
            # Don't allow guest nicks for unauthenticated users matching account pattern
            force-guest-format = false;
          };
        };
      };
    };

    ocf.acme.extraCerts = [ "irc.ocf.berkeley.edu" "irc.ocf.io" ];

    users.users."ergochat" = {
      isNormalUser = true;
      createHome = true;
      group = "acme";
    };
  };
}
