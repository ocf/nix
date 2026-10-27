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
      default = "printhost-dev.ocf.berkeley.edu";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc = {
      "cups/lpoptions".text = "Default OCF-BW";
      "cups/client.conf".text = ''
        ServerName ${cfg.printhostURL}
        Encryption Always
      '';
    };
  };
}
