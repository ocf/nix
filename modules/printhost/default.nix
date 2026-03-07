{ lib, ... }:

{
  imports = [
    ./cups.nix
    ./enforcer.nix
    ./monitor.nix
  ];

  options.ocf.printhost = {
    enable = lib.mkEnableOption "OCF print server";

    redisHost = lib.mkOption {
      type = lib.types.str;
      description = "Hostname of the Redis broker used for desktop notifications.";
    };

    mysqlPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the MySQL password.";
    };

    redisPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Redis broker password.";
    };

    wayoutPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the wayout notification password.";
    };

    _enforcerBackend = lib.mkOption {
      type = lib.types.package;
      internal = true;
      description = "Internal: enforcer CUPS backend script (set by enforcer.nix).";
    };
  };
}
