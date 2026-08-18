{ lib, config, ... }:

{
  imports = [
    ./cups.nix
    ./enforcer.nix
    ./monitor.nix
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

    redisPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Redis broker password.";
    };
  };

  config = lib.mkIf config.ocf.printhost.enable {
    # cups user needs acme group to read /var/lib/acme certs in preStart
    users.users."cups".extraGroups = [ "acme" ];
    # root needs lp group to run lpadmin in the printer setup service
    users.users."root".extraGroups = [ "lp" ];

    # Reload CUPS when the host's LE cert is renewed (cert lives at hostName path,
    # printhost SAN is included as an extraCert below)
    security.acme.certs."${config.networking.hostName}.ocf.berkeley.edu".reloadServices = [
      "cups.service"
    ];

    # add all CNAMEs to tule's cert
    ocf.acme.extraCerts = [
      "printhost.ocf.berkeley.edu"
      "printhost.ocf.io"
      "p.ocf.berkeley.edu"
      "p.ocf.io"
    ];
  };
}
