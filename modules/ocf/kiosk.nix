{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.kiosk;
in
{
  options.ocf.kiosk = {
    enable = lib.mkEnableOption "Enable Kiosk configuration";
    url = lib.mkOption {
      type = lib.types.str;
      description = "URL to open the Kiosk with";
    };
    wlrRandrOptions = lib.mkOption {
      type = lib.types.str;
      description = "Flags to pass to wlr-randr";
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    services.cage = {
      enable = true;
      program = "${lib.getExe pkgs.chromium} --noerrdialogs --disable-infobars --kiosk ${cfg.url}";
      user = "ocftv";
    };

    systemd.services.cage-tty1 = {
      # TODO: Fix this
      # serviceConfig.ExecStartPost = lib.mkIf
      #   (cfg.wlrRandrOptions != null)
      #   "${lib.getExe pkgs.wlr-randr} ${cfg.wlrRandrOptions}";

      after = [ "network-online.target" "systemd-resolved.service" ];
    };
  };
}
