{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.kiosk;
  swayConfig = pkgs.writeText "kiosk-sway-config" ''
    ${cfg.extraConfig}
    include /etc/sway/config
    exec "${lib.getExe pkgs.chromium} --noerrdialogs --disable-infobars --kiosk ${cfg.url}";
    exec "${lib.getExe pkgs.wayvnc} localhost";                                    
  '';
in
{
  options.ocf.kiosk = {
    enable = lib.mkEnableOption "Enable Kiosk configuration";
    url = lib.mkOption {
      type = lib.types.str;
      description = "URL to open the Kiosk with";
    };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      description = "Extra config to pass on to sway";
      default = '''';
    };
  };

  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          command = "${lib.getExe pkgs.sway} --config ${swayConfig}";
          user = "ocftv";
        };
        default_session = initial_session;
      };
    };

    programs.sway.enable = true;
  };
}
