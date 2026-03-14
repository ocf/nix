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
    
    printhostUrl = lib.mkOption {
      type = lib.types.str;
      description = "Printhost URL";
      default = "printhost-dev.ocf.berkeley.edu";
    };

  };

  config = lib.mkIf config.ocf.printhost.enable {
    users.users."cups".extraGroups = [ "acme" ];

    security.acme.defaults.reloadServices = [ "cups.service" ];

    ocf.acme.extraCerts = [
      "printhost-dev.ocf.berkeley.edu"
      "printhost-dev.ocf.io"
    ];
  };
}
