{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "tule";

  ocf.network = {
    enable = true;
    lastOctet = 127;
  };

  ocf.acme = {
    enable = true;
    extraCerts = [
      "printhost-dev.ocf.berkeley.edu"
      "printhost-dev.ocf.io"
    ];
  };

  ocf.printhost = {
    enable = true;
    redisHost = "broker.ocf.berkeley.edu";
    mysqlPasswordFile = config.age.secrets.printhost-mysql-password.path;
    redisPasswordFile = config.age.secrets.printhost-redis-password.path;
    wayoutPasswordFile = config.age.secrets.printhost-wayout-password.path;
  };

  age.secrets.printhost-mysql-password = {
    rekeyFile = ../../secrets/master-keyed/printhost/mysql-password.age;
    mode = "0440";
    group = "lp";
  };
  age.secrets.printhost-redis-password = {
    rekeyFile = ../../secrets/master-keyed/printhost/redis-password.age;
    mode = "0440";
    group = "lp";
  };
  age.secrets.printhost-wayout-password = {
    rekeyFile = ../../secrets/master-keyed/printhost/wayout-password.age;
    mode = "0440";
    group = "lp";
  };

  services.postfix = {
    enable = true;
    domain = "ocf.berkeley.edu";
    origin = "ocf.berkeley.edu";
    config = {
      mydestination = "";
      inet_interfaces = "loopback-only";
      relayhost = ["smtp.ocf.berkeley.edu"];
    };
  };

  system.stateVersion = "25.05";
}
