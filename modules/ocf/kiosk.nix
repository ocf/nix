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
    extraConfig = lib.mkOption {
      type = lib.types.str;
      description = "extra config to pass on to sway";
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {

    programs.sway.enable = true;

    services.greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          command =
            let
              swayConfig = pkgs.writeText "kiosk-sway-config" ''                             
                                                                                               
                ${cfg.extraConfig}
                
                include /etc/sway/config                                                       
                                                                                               
                exec "${lib.getExe pkgs.chromium} --noerrdialogs --disable-infobars --kiosk ${cfg.url}";                                                                 
                exec "${lib.getExe pkgs.wayvnc} localhost";                                    
              '';
            in
            "${lib.getExe pkgs.sway} --config ${swayConfig}";
          user = "ocftv";
        };
        default_session = initial_session;
      };
    };


  };
}
