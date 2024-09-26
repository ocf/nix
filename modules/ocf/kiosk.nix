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
      program = "${lib.getExe pkgs.chromium} --enable-features=UseOzonePlatform --ozone-platform=wayland --noerrdialogs --disable-infobars --kiosk ${cfg.url}";
      user = "ocftv";
    };

    security.pam = {
      services.cage.makeHomeDir = true;
    };

    systemd.services = {
      cage-tty1 = {
        # Patch the provided service to start only after network is online
        after = [ "network-online.target" "systemd-resolved.service" ];
      };

      wlr-randr = {
        description = "Rotate display after cage startup";
        after = [ "cage-tty1.service" ];
        wantedBy = [ "cage-tty1.service" ];

        serviceConfig = {
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
          ExecStart = "${lib.getExe pkgs.wlr-randr} ${cfg.wlrRandrOptions}";
          User = "ocftv";
          PAMName = "cage";
        };
      };
    };
  };
}
