# TODO: Move some of this config to profiles/desktop.nix.
# This file should contain basic DE setup but not the big KDE config, etc.

{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.graphical;
in
{
  options.ocf.graphical = {
    enable = lib.mkEnableOption "Enable desktop environment configuration";
  };

  config = lib.mkIf cfg.enable {
    security.pam = {
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
      initrd.supportedFilesystems = [ "nfs" ];
      kernelModules = [ "nfs" ];
    };

    environment.etc = {
      skel.source = ./graphical/skel;
      ocf-assets.source = ./graphical/assets;
    };

    programs.steam.enable = true;

    environment.systemPackages = with pkgs; [
      plasma-applet-commandoutput
      (catppuccin-sddm.override {
        themeConfig.General = {
          FontSize = 12;
          Background = "/etc/ocf-assets/images/login-winter.png";
          #Logo = "/etc/ocf-assets/images/penguin.svg";
          CustomBackground = true;
        };
      })
      libreoffice
      vscode-fhs
      kitty
      prismlauncher

      # Okular prints PDFs weird, requiring force rasterization. Instead, we use
      # the new GNOME viewer called Papers, patched to add a bigger Print button
      ocf-papers

      # temporary ATDP programs
      filezilla
      sublime
    ];

    fonts.packages = with pkgs; [ meslo-lgs-nf noto-fonts noto-fonts-cjk noto-fonts-extra ];

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

    # Mount user homes from NFS
    fileSystems."/remote/home" = {
      device = "homes:/home";
      fsType = "nfs";
      # Don't automatically mount, mount when accessed, umount after 10min idle
      options = [ "noauto" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
    };

    # KDE 6.0.3 has a bug that breaks logging out within the first 60 seconds.
    # This is caused by the DrKonqi service's ExecStartPre command, which sleeps
    # for 60 seconds to let the system settle before monitoring coredumps. We
    # don't need this wait, so we remove the ExecStartPre entry.
    systemd.user.services.drkonqi-coredump-pickup.unitConfig.ExecStartPre = lib.mkForce [ ];

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
      script = ''
        [ -f ~/remote/.desktoprc ] && . ~/remote/.desktoprc
      '';
    };

    systemd.user.services.link-user-remote = {
      description = "SymLink ~/remote from NFS mount";
      script = ''
        if [[ ! -h "$HOME/remote" ]]; then
          ln -s "/remote$HOME" "$HOME/remote"
        fi
      '';
    };

    systemd.user.services.home-manager = {
      description = "load custom home manager config if present";
      requires = [ "link-user-remote.service" ];
      after = [ "link-user-remote.service" ];
      wantedBy = [ "default.target" ];
      path = [ pkgs.nix pkgs.git ];
      script = ''
        # Will create a template directory if it doesn't exist. Maybe look into creating
        # our own template repo as currently users will need to edit nix files to get 
        # custom packages etc...
        nix run home-manager -- init --switch ~/remote/.home-manager
      '';
    };

    # Conflict override since multiple DEs set this option
    programs.ssh.askPassword = pkgs.lib.mkForce (lib.getExe pkgs.ksshaskpass.out);
  };
}
