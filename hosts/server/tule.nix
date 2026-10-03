{ config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  ocf.network = {
    enable = true;
    lastOctet = 127;
  };

  ocf.acme.enable = true;

  ocf.printhost = {
    enable = true;
    mysqlPasswordFile = config.age.secrets.printhost-mysql-password.path;
    wayoutPasswordFile = config.age.secrets.printhost-wayout-password.path;
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

  system.stateVersion = "25.05";
}
