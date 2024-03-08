{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.ocf.de;
in
{
  options.ocf.de = {
    enable = mkEnableOption "Enable desktop environment configuration";
  };

  config = mkIf cfg.enable {
    environment.etc = {
      skel.source = ./de/skel;
      "ocf/assets".source = ./de/assets;
    };

    security.pam = {
      services.systemd-user.makeHomeDir = true;
      makeHomeDir.skelDirectory = "/etc/skel";
    };

    environment.systemPackages = with pkgs; [
      google-chrome
      firefox
      libreoffice
      vscode-fhs
    ];

    services.xserver = {
      enable = true;

      # KDE is our primary DE, but have others available
      desktopManager.plasma6.enable = true;
      desktopManager.gnome.enable = true;
      desktopManager.xfce.enable = true;

      displayManager = {
        defaultSession = "plasma";

        sddm = {
          enable = true;
          theme = "breeze";
          wayland.enable = true;
          settings.Users = {
            RememberLastUser = false;
            RememberLastSession = false;
          };
        };
      };

      xkb = {
        layout = "us";
        variant = "";
      };
    };

    systemd.user.services.wayout = {
      description = "Automatic idle logout manager";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.ocf.wayout}/bin/wayout";
        Type = "simple";
        Restart = "on-failure";
      };
    };

    # Conflict override since multiple DEs set this option
    programs.ssh.askPassword = pkgs.lib.mkForce "${pkgs.ksshaskpass.out}/bin/ksshaskpass";
  };
}
