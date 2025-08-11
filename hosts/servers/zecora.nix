{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "zecora";
  # TODO: Move IRC related config into a custom OCF module

  ocf.network = {
    enable = true;
    lastOctet = 44;
  };

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
        motd = pkgs.writeText "ircd.motd" "hiiiii";
        sts.enabled = true;
        listeners.":6697".tls = {
          cert = "/var/lib/acme/zecora.ocf.berkeley.edu/fullchain.pem";
          key = "/var/lib/acme/zecora.ocf.berkeley.edu/key.pem";
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

  system.stateVersion = "24.11";
}
