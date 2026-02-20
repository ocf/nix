{ lib, config, ... }:

let
  cfg = config.ocf.network.bond;
in
{
  options.ocf.network.bond = {
    enable = lib.mkEnableOption "Enable bonding network interfaces";
    interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Name of the network interfaces to bond";
    };
    bondInterface = lib.mkOption {
      type = lib.types.str;
      description = "Name of the bonded interface";
      default = "bond0";
    };
  };

  config = lib.mkIf cfg.enable {
    ocf.network.interface = cfg.bondInterface;

    systemd.network = {
      enable = true;

      netdevs."10-${cfg.bondInterface}" = {
        netdevConfig = {
          Name = cfg.bondInterface;
          Kind = "bond";
        };
        bondConfig = {
          Mode = "802.3ad";
          TransmitHashPolicy = "layer3+4";
          MIIMonitorSec = "100ms";
          LACPTransmitRate = "fast";
        };
      };

      networks = lib.listToAttrs (map
        (interface: {
          name = "10-${interface}";
          value = {
            matchConfig.Name = interface;
            networkConfig.Bond = cfg.bondInterface;
          };
        })
        cfg.interfaces);
    };
  };
}
