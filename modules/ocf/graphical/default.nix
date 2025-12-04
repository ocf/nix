# TODO: Move some of this config to profiles/desktop.nix.
# This file should contain basic DE setup but not the big KDE config, etc.

{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.graphical;

  # Default openssh doesn't include GSSAPI support, so we need to override sshfs
  # to use the openssh_gssapi package instead. This is annoying because the
  # sshfs package's openssh argument is nested in another layer of callPackage,
  # so we override callPackage instead to override openssh.
  sshfs = pkgs.sshfs.override {
    callPackage = fn: args: (pkgs.callPackage fn args).override {
      openssh = pkgs.openssh_gssapi;
    };
  };
in
{
  options.ocf.graphical = {
    enable = lib.mkEnableOption "Enable desktop environment configuration";
  };

  config = lib.mkIf cfg.enable {
    security.pam = {
      # Mount ~/remote
      services.login.pamMount = true;
      services.login.rules.session.mount.order = config.security.pam.services.login.rules.session.krb5.order + 50;
      mount.extraVolumes = [ ''<volume fstype="fuse" path="${lib.getExe sshfs}#%(USER)@tsunami:" mountpoint="~/remote/" options="follow_symlinks,UserKnownHostsFile=/dev/null,StrictHostKeyChecking=no" pgrp="ocf" />'' ];

      # Trim spaces from username
      services.login.rules.auth.trimspaces = {
        control = "requisite";
        modulePath = "${pkgs.ocf-pam_trimspaces}/lib/security/pam_trimspaces.so";
        order = 0;
      };

      # This contains a bunch of KDE, etc. configs
      makeHomeDir.skelDirectory = "/etc/skel";
    };

    boot = {
      loader.timeout = 0;
      initrd.systemd.enable = true;
    };

    environment.etc = {
      skel.source = ./skel;
      ocf-assets.source = ./assets;
    };

    programs = {
      steam.enable = true;
      zoom-us.enable = true;
      sway.enable = true;
      sway.extraOptions = [ "--unsupported-gpu" ];
      hyprland.enable = true;
      wayfire.enable = true;
      niri.enable = true;
    };

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

    environment.systemPackages = with pkgs; [
      plasma-applet-commandoutput
      (catppuccin-sddm.override {
        themeConfig.General = {
          FontSize = 12;
          Background = "/etc/ocf-assets/images/login.png";
          #Logo = "/etc/ocf-assets/images/penguin.svg";
          CustomBackground = true;
        };
      })

      libreoffice

      # terminal emulators
      foot
      kitty
      alacritty
      st
      ghostty

      # IRC Clients
      irssi
      weechat
      hexchat
      halloy

      gimp3
      inkscape
      blender
      xournalpp
      fastfetch

      ocf-okular
      ocf-papers

      # TEXT & CODE EDITORS
      vscode-fhs
      rstudio
      zed-editor
      jetbrains.idea-community

      # GAMES
      dwarf-fortress
      prismlauncher
      unciv
      superTuxKart
      tetris

    ];

    fonts.packages = with pkgs; [ meslo-lgs-nf noto-fonts noto-fonts-cjk-sans ];

    services = {
      # KDE Plasma is our primary DE, but have others available
      desktopManager.plasma6.enable = true;
      xserver.desktopManager = {
        gnome.enable = true;
        xfce.enable = true;
      };

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
