# basic minimal profile for desktops

{ config, pkgs, lib, inputs, ... }:

# TODO: Move this to pkgs/ or come up with a better way to manage custom scripts
let
  vncScript = pkgs.writeShellScriptBin "ocf-tv" ''
    ${lib.getExe pkgs.openssh_gssapi} -M -S /tmp/ocftv-ssh-ctl -fNT -L 5900:localhost:5900 tornado
    ${lib.getExe pkgs.remmina} --no-tray-icon --disable-news --disable-stats --enable-extra-hardening -c vnc://localhost
    ${lib.getExe pkgs.openssh_gssapi} -S /tmp/ocftv-ssh-ctl -O exit tornado
  '';
  # override ocf-tv from util
  ocf-tv = lib.hiPrio vncScript;

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

  # Colmena tagging
  deployment.tags = [ "desktop" ];

  ocf = {
    # TODO: need ensure host keys can't be stolen by booting an external drive...
    acme.enable = false;

    etc.enable = true;
    graphical.enable = true;
    graphical.install-extra-apps = true;
    browsers.enable = true;
    tmpfsHome.enable = true;
    network.wakeOnLan.enable = true;
    logged-in-users-exporter.enable = true;
  };

  boot = {
    loader.systemd-boot.consoleMode = "max";
    loader.timeout = 0;
    initrd.systemd.enable = true;
  };

  # Enable support SANE scanners
  hardware.sane.enable = true;

  zramSwap.enable = true;

  documentation.dev.enable = true;

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

  environment.systemPackages = with pkgs; [
    lf
    dua
    tree
    tmux

    ocf-tv

    # COSMIC Applets
    ocf-cosmic-applets

    # IRC password prompt
    kdePackages.kdialog
  ];

  services = {
    avahi.enable = true;

    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
    };
  };

  security.rtkit.enable = true;
  services.pulseaudio.enable = false;

  # needed for accessing totp codes on yubikey via yubico authenticator
  services.pcscd.enable = true;

  # enable secure attention key (also enables unraw/xlate)
  boot.kernel.sysctl."kernel.sysrq" = 4;

  # Needed for generic Linux programs
  # More info: https://nix.dev/guides/faq#how-to-run-non-nix-executables
  programs.nix-ld.enable = true;
}
