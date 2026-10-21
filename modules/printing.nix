{
  lib,
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
      startWhenNeeded = false; # print dialog does not wait for cups to start, will show no printers first time if socket-activated
      browsed.enable = false;
      browsing = false;
      stateless = true;
    };
    hardware.printers = {
      ensureDefaultPrinter = "OCF-BW";
      ensurePrinters = [
        {
          deviceUri = "ipps://${cfg.printhostURL}/classes/OCF-BW-Group";
          name = "OCF-BW";
          model = "everywhere";
        }
        {
          deviceUri = "ipps://${cfg.printhostURL}/classes/fishpaper";
          name = "OCF-Color";
          model = "everywhere";
        }
      ];
    };
  };
}
