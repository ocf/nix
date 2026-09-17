{ lib, config, ... }:

let
  cfg = config.ocf.printhost;
in
{
  imports = [
    ./cups.nix
    ./cleanup.nix
  ];

  options.ocf.printhost = {
    enable = lib.mkEnableOption "OCF print server";

    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "sets SUBDOMAIN.ocf.berkeley.edu and SUBDOMAIN.ocf.io";
      default = "printhost";
    };

    mysqlPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the MySQL password.";
    };

    wayoutPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the wayout notification password.";
    };
  };

  config = lib.mkIf config.ocf.printhost.enable {
    # cups user needs acme group to read /var/lib/acme certs in preStart
    users.users."cups".extraGroups = [ "acme" ];
    # root needs lp group to run lpadmin in the printer setup service
    users.users."root".extraGroups = [ "lp" ];

    # reload cups when the host's tls cert is renewed
    # and link certs to the paths cups expects (cups pointed to /var/lib/acme in cups-files.conf)
    security.acme.certs."${config.networking.fqdn}" = {
      reloadServices = [ "cups.service" ];
      postRun = ''
        ln -sf /var/lib/acme/${config.networking.fqdn}/fullchain.pem \
          /var/lib/acme/${config.networking.fqdn}.crt
        ln -sf /var/lib/acme/${config.networking.fqdn}/key.pem \
          /var/lib/acme/${config.networking.fqdn}.key
      '';
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

    # add all CNAMEs to tule's cert
    ocf.acme.extraCerts = [
      "${cfg.subdomain}.ocf.berkeley.edu"
      "${cfg.subdomain}.ocf.io"
    ];
  };
}
