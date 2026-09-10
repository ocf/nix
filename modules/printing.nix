{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.ocf.printing;
in
{
  options.ocf.printing = {
    enable = lib.mkEnableOption "OCF client printing support";

    printhostURL = lib.mkOption {
      type = lib.types.str;
      default = "printhost.ocf.berkeley.edu";
    };
  };

  config = lib.mkIf cfg.enable {
    services.avahi.enable = lib.mkForce false; # prevent printer discovery by cups client
    services.printing = {
      enable = true;
      startWhenNeeded = true;
      browsed.enable = false;
      browsing = false;
      drivers = [ pkgs.ocf-hplip ];
    };
    hardware.printers = {
      ensureDefaultPrinter = "OCF-BW";
      ensurePrinters = [
        {
          deviceUri = "ipps://${cfg.printhostURL}/classes/OCF-BW-Group?waitjob=false&waitprinter=false";
          name = "OCF-BW";
          model = "HP/hp-laserjet_m806-ps.ppd.gz";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "DuplexNoTumble";
          };
        }
        {
          deviceUri = "ipps://${cfg.printhostURL}/classes/OCF-Color?waitjob=false&waitprinter=false";
          name = "OCF-Color";
          model = "HP/hp-color_laserjet_m856-ps.ppd.gz";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "None";
          };
        }
      ];
    };
  };
}
