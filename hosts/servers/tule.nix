{ config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "tule";

  ocf.network = {
    enable = true;
    lastOctet = 127;
  };

  ocf.acme.enable = true;

  ocf.printhost = {
    enable = true;
    mysqlPasswordFile = config.age.secrets.printhost-mysql-password.path;
    wayoutPasswordFile = config.age.secrets.printhost-wayout-password.path;
    redisPasswordFile = config.age.secrets.printhost-redis-password.path;
    # TODO: change to "printhost.ocf.berkeley.edu" once tule replaces whiteout
    printhostUrl = "printhost-dev.ocf.berkeley.edu";
  };

  age.secrets.printhost-mysql-password = {
    rekeyFile = ../../secrets/master-keyed/printhost/mysql-password.age;
    mode = "0440";
    group = "lp";
  };
  age.secrets.printhost-wayout-password = {
    rekeyFile = ../../secrets/master-keyed/printhost/wayout-password.age;
    mode = "0440";
    group = "lp";
  };
  age.secrets.printhost-redis-password = {
    rekeyFile = ../../secrets/master-keyed/printhost/redis-password.age;
    mode = "0440";
    group = "lp";
  };

  # Postfix relay so ocflib can send mail via sendmail.
  services.postfix = {
    enable = true;
    settings.main = {
      mydomain = "ocf.berkeley.edu";
      myorigin = "ocf.berkeley.edu";
      mydestination = "";
      inet_interfaces = "loopback-only";
      relayhost = [ "smtp.ocf.berkeley.edu" ];
      sender_canonical_maps = "static:root@ocf.berkeley.edu";
    };
  };

  system.stateVersion = "25.05";
}
