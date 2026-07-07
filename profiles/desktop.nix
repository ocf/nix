# basic minimal profile for desktops

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  ocf = {
    # TODO: need ensure host keys can't be stolen by booting an external drive...
    acme.enable = false;

    home.tmpfs = true;
    home.mountRemote = true;
    network.wakeOnLan.enable = true;
    logged-in-users-exporter.enable = true;

    zfs.enable = true;

    gui.enable = true;
    gui.apps.enable = true;

    cli.apps.enable = true;
  };

  boot = {
    loader.systemd-boot.consoleMode = "max";
    loader.timeout = 0;
    initrd.systemd.enable = true;
  };

  # FIXME: suspend causes problems with nfs. disable until we fix this
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  # Enable support SANE scanners
  hardware.sane.enable = true;

  zramSwap.enable = true;

  documentation.dev.enable = true;

  environment.shellAliases.quota = "quota -Qs";

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

  # kill user processes on logout
  # if this is not set to true, the system user manager, processes, home tmpfs
  # mount, etc will linger, causing the logind session and scope to be stuck in
  # "closing" and "abandoned" respectively. this is undesired behavior on a
  # shared desktop machine.
  services.logind.settings.Login.KillUserProcesses = true;

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
