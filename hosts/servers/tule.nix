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
    printhostUrl = "printhost.ocf.berkeley.edu";
    printerCerts = {
      adminPasswordFile = config.age.secrets.printer-admin-password.path;
      printerUrls = [
        "logjam.ocf.berkeley.edu"
        "papercut.ocf.berkeley.edu"
        "pagefault.ocf.berkeley.edu"
        "fishpaper.ocf.berkeley.edu"
      ];
    };
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
  age.secrets.printer-admin-password = {
    rekeyFile = ../../secrets/master-keyed/printhost/printer-admin-password.age;
    mode = "0400";
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
