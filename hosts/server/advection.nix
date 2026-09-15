{ config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  ocf.network = {
    enable = true;
    lastOctet = 126;
  };

  ocf.acme.enable = true;

  ocf.printhost = {
    enable = true;
    subdomain = "printhost-dev";
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

  # Postfix relay so ocflib can send mail via sendmail.
  services.postfix = {
    enable = true;
    settings.main = {
      mydomain = config.networking.domain;
      myorigin = config.networking.domain;
      mydestination = "";
      inet_interfaces = "loopback-only";
      relayhost = [ "smtp.${config.networking.domain}" ];
      sender_canonical_maps = "static:root@${config.networking.domain}";
    };
  };

  system.stateVersion = "26.05";
}
