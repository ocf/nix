{
  config,
  pkgs,
  lib,
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
      default = "printhost-dev.ocf.berkeley.edu";
    };
  };

  config = lib.mkIf cfg.enable {
    services.avahi.enable = lib.mkForce false; # prevent printer discovery by cups client
    services.printing = {
      enable = true;
      startWhenNeeded = false; # print dialog does not wait for cups to start, will show no printers first time if socket-activated
      browsed.enable = false;
      browsing = false;
      stateless = true;
      drivers = [
        (pkgs.writeTextDir "share/cups/model/OCF-BW-Group.ppd" (builtins.readFile ./OCF-BW-Group.ppd))
      ];
    };
    hardware.printers = {
      ensureDefaultPrinter = "OCF-BW";
      ensurePrinters = [
        {
          deviceUri = "ipps://${cfg.printhostURL}/classes/OCF-BW-Group?waitjob=false&waitprinter=false";
          name = "OCF-BW";
          model = "OCF-BW-Group.ppd"; # generated ppd from `logjam`
          location = "OCF lab";
          ppdOptions = {
            Duplex = "DuplexNoTumble";
          };
        }
        {
          deviceUri = "ipps://${cfg.printhostURL}/printers/fishpaper?waitjob=false&waitprinter=false";
          name = "OCF-Color";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "None";
          };
        }
      ];
    };
  };
}
