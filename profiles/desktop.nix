# basic minimal profile for desktops

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{

  # Colmena tagging
  deployment.tags = [ "desktop" ];
  system.nixos.variant_id = "ocf-desktop";

  ocf = {
    # TODO: need ensure host keys can't be stolen by booting an external drive...
    acme.enable = false;

    etc.enable = true;
    home.tmpfs = true;
    network.wakeOnLan.enable = true;
    logged-in-users-exporter.enable = true;

    nfs = {
      enable = true;
      mount = true;
      kerberos = true;
      softerr = true;

      # we keep a single nfs mount and then bind mount to it instead of having
      # many nfs mounts (each logged in user would need a mount)
      asRemote = true;
    };

    graphical.enable = true;
    graphical.extra = true;

    userPackages.enable = true;
  };

  boot = {
    loader.systemd-boot.consoleMode = "max";
    loader.timeout = 0;
    initrd.systemd.enable = true;

    # zen kernel for a more responsive desktop
    kernelPackages = pkgs.linuxPackages_zen;
  };

  # Enable support SANE scanners
  hardware.sane.enable = true;

  zramSwap.enable = true;

  documentation.dev.enable = true;

  security.pam = {
    # Mount ~/remote
    services.login.pamMount = true;
    services.login.rules.session.mount.order =
      config.security.pam.services.login.rules.session.krb5.order + 50;
    mount.extraVolumes = [
      ''<volume fstype="bind" path="/remote/$(USER:0:1)/$(USER:0:2)/$(USER)" mountpoint="$(HOME)/remote/" />''
    ];

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

    # COSMIC Applets
    ocf-cosmic-applets
    cosmic-ext-applet-external-monitor-brightness

    # IRC password prompt
    kdePackages.kdialog

    ddcutil # for monitor brightness control
  ];

  # enable i2c and set udev rules for monitor brightness control
  boot.kernelModules = [ "i2c-dev" ];
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", RUN+="${pkgs.coreutils}/bin/chgrp 1000 /dev/%k", RUN+="${pkgs.coreutils}/bin/chmod 0660 /dev/%k"
  '';

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

  virtualisation.podman.enable = true;

  # enable secure attention key (also enables unraw/xlate)
  boot.kernel.sysctl."kernel.sysrq" = 4;

  # Needed for generic Linux programs
  # More info: https://nix.dev/guides/faq#how-to-run-non-nix-executables
  programs.nix-ld.enable = true;

  # Add forward flag to tickets on desktops
  security.krb5.settings.libdefaults.forwardable = true;

  # Only forward Kerberos tickets to login servers (carp and koi)
  programs.ssh.extraConfig = lib.mkOverride 90 ''
    CanonicalizeHostname yes
    CanonicalDomains ocf.berkeley.edu
    Host carp.ocf.berkeley.edu koi.ocf.berkeley.edu
        GSSAPIAuthentication yes
        GSSAPIKeyExchange yes
        GSSAPIDelegateCredentials yes
    Host *.ocf.berkeley.edu *.ocf.io 169.229.226.* 2607:f140:8801::*
        GSSAPIAuthentication yes
        GSSAPIKeyExchange yes
  '';
}
