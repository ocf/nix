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
    rekeyFile = ../../secrets/master-keyed/printhost-mysql-password.age;
  };
  age.secrets.printhost-redis-password = {
    rekeyFile = ../../secrets/master-keyed/printhost-redis-password.age;
  };
  age.secrets.printhost-wayout-password = {
    rekeyFile = ../../secrets/master-keyed/printhost-wayout-password.age;
  };

  system.stateVersion = "25.05";
}
