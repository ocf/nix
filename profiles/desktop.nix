# basic minimal profile for desktops

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Default openssh doesn't include GSSAPI support, so we need to override sshfs
  # to use the openssh_gssapi package instead. This is annoying because the
  # sshfs package's openssh argument is nested in another layer of callPackage,
  # so we override callPackage instead to override openssh.
  sshfs = pkgs.sshfs.override {
    callPackage =
      fn: args:
      (pkgs.callPackage fn args).override {
        openssh = pkgs.openssh_gssapi;
      };
  };
in
{

  # Colmena tagging
  deployment.tags = [ "desktop" ];
  system.nixos.variant_id = "ocf-desktop";

  ocf = {
    # TODO: need ensure host keys can't be stolen by booting an external drive...
    acme.enable = false;

    etc.enable = true;
    tmpfsHome.enable = true;
    network.wakeOnLan.enable = true;
    logged-in-users-exporter.enable = true;

    graphical.enable = true;
    graphical.extra = true;
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
      ''<volume fstype="fuse" path="${lib.getExe sshfs}#%(USER)@tsunami:" mountpoint="~/remote/" options="follow_symlinks,UserKnownHostsFile=/dev/null,StrictHostKeyChecking=no" pgrp="ocf" />''
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
  ];

  services = {
    avahi.enable = true;

    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
    };

    # Local CUPS daemon required for cups-browsed to create forwarding queues.
    # cups-browsed polls the OCF print server and clusters all printers into a
    # single "OCF" queue on the client, fixing copies-supported and giving users
    # full PPD option access (duplex, color) in the print dialog.
    printing = {
      enable = true;
      startWhenNeeded = true;
      extraConf = "DefaultPrinter OCF-BW";
      browsed.enable = true;
      browsedConf = ''
        BrowsePoll printhost-dev.ocf.berkeley.edu:631
        BrowseRemoteProtocols none
        BrowseInterval 300
        BrowseTimeout 1500
        AutoClustering No
        Cluster OCF-BW: logjam pagefault papercut
        Cluster OCF-Color: epson
        LoadBalancing QueueOnServers
      '';
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
