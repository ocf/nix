{ lib, config, ... }:

let
  cfg = config.ocf.network;
in
{
  imports = [ ./bond.nix ];

  options.ocf.network = {
    enable = lib.mkEnableOption "Enable OCF network configuration";
    interface = lib.mkOption {
      type = lib.types.str;
      description = "Name of the network interface to configure";
      default = "en*";
    };
    lastOctet = lib.mkOption {
      type = lib.types.int;
      description = "Last octet of the IP address";
    };
    extraRoutes = lib.mkOption {
      type = lib.types.anything;
      description = "Extra routes to place in the systemd-networkd config";
      default = [ ];
    };

    wakeOnLan.enable = lib.mkEnableOption "Enable Wake-on-LAN";
  };

  config = lib.mkIf cfg.enable {
    networking.useDHCP = false;

    systemd.network = {
      enable = true;

      links."10-wired" = lib.mkIf cfg.wakeOnLan.enable {
        matchConfig = {
          OriginalName = cfg.interface;
          Property = "!ID_BUS=usb";
        };
        linkConfig.WakeOnLan = "magic";
      };

      networks."10-wired" = {
        matchConfig = {
          Name = cfg.interface;
          Property = "!ID_BUS=usb";
        };
        linkConfig.RequiredForOnline = "routable";
        address = [
          "169.229.226.${toString cfg.lastOctet}/24"
          "2607:f140:8801::1:${toString cfg.lastOctet}/64"
        ];
        routes = [
          { Gateway = "169.229.226.1"; }
          { Gateway = "2607:f140:8801::1"; }
        ] ++ cfg.extraRoutes;
        dns = [ "169.229.226.22" "2607:f140:8801::1:22" "1.1.1.1" ];
        domains = [ "ocf.berkeley.edu" "ocf.io" ];
      };
    };
  };
}
