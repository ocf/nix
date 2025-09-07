{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.irc;
in
{
  options.ocf.irc = {
    enable = lib.mkEnableOption "Enable IRC Server";
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
    age.secrets.irc-passwd.rekeyFile = ../../secrets/master-keyed/irc-passwd.age;
    security.acme.defaults.reloadServices = [ "ergochat.service" ];

    system.activationScripts."irc-passwd" = ''
      secret=$(cat "${config.age.secrets.irc-passwd.path}")
      configFile=/etc/ergo.yaml
      ${lib.getExe pkgs.gnused} -i "s/@irc-passwd@/$secret/g" "$configFile"
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
