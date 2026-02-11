# This file should contain basic DE setup but not the big KDE config, etc.

{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.graphical;
in
{
  imports = [
    ./install-extra-apps.nix
  ];

  options.ocf.graphical = {
    enable = lib.mkEnableOption "Enable desktop environment configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.sway.enable = true;
    programs.sway.extraOptions = [ "--unsupported-gpu" ];
    programs.hyprland.enable = true;
    programs.wayfire.enable = true;

    services.gnome.gcr-ssh-agent.enable = false;

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.waylandFrontend = true;
      fcitx5.addons = with pkgs; [
        fcitx5-gtk
        fcitx5-mozc
        fcitx5-rime
        fcitx5-hangul
        kdePackages.fcitx5-unikey
        fcitx5-bamboo
        fcitx5-m17n
      ];
    };

    environment.cosmic.excludePackages = [
      pkgs.cosmic-initial-setup
    ];

    environment.etc = {
      skel.source = ./skel;
      ocf-assets.source = ./assets;
    };

    environment.systemPackages = with pkgs; [
      plasma-applet-commandoutput
      (catppuccin-sddm.override {
        themeConfig.General = {
          FontSize = 12;
          Background = "/etc/ocf-assets/images/login-newyear.png";
          #Logo = "/etc/ocf-assets/images/penguin.svg";
          CustomBackground = true;
        };
      })

      # terminal emulators
      kitty
      foot

      # misc wayland utils
      wl-clipboard
      libnotify
    ];

    fonts.packages = with pkgs; [ meslo-lgs-nf noto-fonts noto-fonts-cjk-sans ];

    services = {
      # KDE Plasma is our primary DE, but have others available
      desktopManager = {
        plasma6.enable = true;
        gnome.enable = true;

        cosmic = {
          enable = true;
          showExcludedPkgsWarning = false;
        };
      };
      xserver.desktopManager.xfce.enable = true;

      displayManager = {
        defaultSession = "plasma";

        sddm = {
          enable = true;
          theme = "catppuccin-latte";
          wayland.enable = true;
          settings.Users = {
            RememberLastUser = false;
            RememberLastSession = false;
          };
        };
      };
    };

    systemd.user.services.wayout = {
      description = "Automatic idle logout manager";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.ocf-wayout}/bin/wayout";
        Type = "simple";
        Restart = "on-failure";
      };
    };

    systemd.user.services.desktoprc = {
      description = "Source custom rc shared across desktops";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      environment = { PATH = lib.mkForce "/run/current-system/sw/bin"; };
      script = ''
        if [ -f ~/remote/.desktoprc ]; then
          . ~/remote/.desktoprc
        else
          echo "User doesn't have a ~/remote/.desktoprc file"
        fi
          
      '';
    };

    # Conflict override since multiple DEs set this option
    programs.ssh.askPassword = pkgs.lib.mkForce (lib.getExe pkgs.ksshaskpass.out);
  };
}
