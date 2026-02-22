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
    desktop = lib.mkOption {
      type = lib.types.str;
      description = "Default desktop environment from display manager";
      default = "cosmic";
    };
  };


  config = lib.mkIf cfg.enable {
    programs.sway.enable = true;
    programs.sway.extraOptions = [ "--unsupported-gpu" ];
    programs.hyprland.enable = true;
    programs.wayfire.enable = true;
    programs.niri.enable = true;
    programs.obs-studio.enable = true;
    programs.obs-studio.enableVirtualCamera = true;

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
        defaultSession = cfg.desktop;

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

    systemd.user.services.cosmic-scale = {
      description = "Set COSMIC display scaling";
      after = [ "cosmic-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "cosmic-session.target" ];
      environment = { PATH = lib.mkForce "/run/current-system/sw/bin"; };
      script = ''
        # Set 175% scaling for all enabled displays
        ${pkgs.cosmic-randr}/bin/cosmic-randr list | grep "(enabled)" | sed 's/\x1b[[0-9;]*m//g' | awk '{print $1}' | while read -r output; do
        # Get current mode for this output
        mode=$(${pkgs.cosmic-randr}/bin/cosmic-randr list | awk '/(current)/ {gsub(/\x1b[[0-9;]*m/, ""); print $1, $3;
  exit}')
          if [ -n "$mode" ]; then
            width=$(echo "$mode" | cut -d'x' -f1)
            height=$(echo "$mode" | cut -d'x' -f2 | cut -d' ' -f1)
            scale=1.25
            if [[ "$height" -ge "2160" ]]; then
                scale=1.5
            fi
            ${pkgs.cosmic-randr}/bin/cosmic-randr mode "$output" "$width" "$height" --scale "$scale"
          fi
        done
      '';
    };

  ## Generate Halloy IRC config
  # First, checks for plaintext password file at ~/remote/.config/hallow/nickserv-password.
  # If that doesn't exist, prompts for password with kdialog gui.
  systemd.user.services."halloy-config" = {
    description = "Generate default halloy IRC config with OCF username";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p $HOME/.config/halloy
      cat > $HOME/.config/halloy/config.toml << EOF
  [servers.ocf]
  nickname = "$USER"
  server = "irc.ocf.berkeley.edu"

  [servers.ocf.sasl.plain]
  username = "$USER"
  password_command = 'sh -c "cat ~/remote/.config/ocf/halloy/nickserv-password 2>/dev/null || kdialog --password \"NickServ password (leave blank if not registered)\""'
  EOF
    '';
  };


    # Conflict override since multiple DEs set this option
    programs.ssh.askPassword = pkgs.lib.mkForce (lib.getExe pkgs.ksshaskpass.out);
  };
}
