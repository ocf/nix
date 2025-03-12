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
      skel.source = ./graphical/skel;
      ocf-assets.source = ./graphical/assets;
    };

    programs.steam.enable = true;

    environment.systemPackages = with pkgs; [
      libreoffice
      vscode-fhs
      kitty
      prismlauncher
      unciv
      rstudio

      ocf-okular

      # temporary ATDP programs
      filezilla
      # sublime
    ];

    fonts.packages = with pkgs; [ meslo-lgs-nf noto-fonts noto-fonts-cjk-sans noto-fonts-extra ];

    services = {
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
      script = ''
        [ -f ~/remote/.desktoprc ] && . ~/remote/.desktoprc
      '';
    };

    # Conflict override since multiple DEs set this option
    programs.ssh.askPassword = pkgs.lib.mkForce (lib.getExe pkgs.ksshaskpass.out);
  };
}
