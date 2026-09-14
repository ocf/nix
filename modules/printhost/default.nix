{ lib, config, ... }:

{
  imports = [
    ./cups.nix
    ./cleanup.nix
  ];

  options.ocf.printhost = {
    enable = lib.mkEnableOption "OCF print server";

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
    # and link certs to the paths cups expects (cups pointed to /etc/cups-certs in cups-files.conf)
    security.acme.certs."${config.networking.fqdn}".reloadServices = [ "cups.service" ];
    environment.etc = {
      "cups-certs/${config.networking.fqdn}.crt".source =
        "/var/lib/acme/${config.networking.fqdn}/fullchain.pem";
      "cups-certs/${config.networking.fqdn}.key".source =
        "/var/lib/acme/${config.networking.fqdn}/key.pem";
    };

    # add all CNAMEs to tule's cert
    ocf.acme.extraCerts = [
      "printhost.ocf.berkeley.edu"
      "printhost.ocf.io"
      "p.ocf.berkeley.edu"
      "p.ocf.io"
    ];
  };
}
