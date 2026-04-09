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

  # Same PPDs as the print server — the client runs the filter chain locally
  # so users get full option access (duplex, paper size, etc.) in the print
  # dialog, then sends the processed job to the server class.
  hpPpd = "${pkgs.hplip}/share/cups/model/HP/hp-laserjet_m806-ps.ppd.gz";
  epsonPpd = "${pkgs.epson-escpr2}/share/cups/model/epson-inkjet-printer-escpr2/Epson-ET-5880_Series-epson-escpr2-en.ppd";
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

    # Local CUPS daemon with statically configured queues pointing at the print
    # server. The client runs the HP/Epson filter chains locally (giving users
    # full PPD option access in the print dialog), then forwards the processed
    # job to the server. OCF-BW targets the server-side class so the server
    # distributes to whichever physical printer is free.
    printing = {
      enable = true;
      startWhenNeeded = true;
      stateless = true;
      extraConf = ''
        DefaultPrinter OCF-BW
        Browsing Off
        ErrorPolicy abort-job
      '';
      drivers = with pkgs; [ hplip epson-escpr2 ];
    };
  };

  # Recreate print queues on every boot (stateless = true clears /var/lib/cups).
  # Mirrors the cups-setup-printers pattern on the print server.
  systemd.services.cups-client-setup = {
    description = "Configure CUPS client print queues";
    after = [ "cups.service" ];
    wants = [ "cups.service" ];
    wantedBy = [ "cups.service" ];
    partOf = [ "cups.service" ];
    path = [ config.services.printing.package ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      for i in $(seq 1 30); do
        if lpstat -H >/dev/null 2>&1; then break; fi
        sleep 2
      done

      # OCF-BW: points at the server-side class, which distributes to
      # logjam/pagefault/papercut. The server uses socket backends so jobs
      # complete as soon as data is written — no waiting for physical printing.
      lpadmin -p OCF-BW \
        -v ipps://printhost-dev.ocf.berkeley.edu/classes/OCF-BW \
        -P ${hpPpd} \
        -D "OCF Black & White" -L "OCF lab" \
        -E -o printer-is-shared=false -o Duplex=DuplexNoTumble

      lpadmin -p OCF-Color \
        -v ipps://printhost-dev.ocf.berkeley.edu/printers/epson \
        -P ${epsonPpd} \
        -D "OCF Color" -L "OCF lab" \
        -E -o printer-is-shared=false -o Duplex=DuplexNoTumble -o PageSize=Letter
    '';
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
