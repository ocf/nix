# basic minimal profile for desktops

{ pkgs, lib, inputs, ... }:

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
  };

  boot = {
    loader.systemd-boot.consoleMode = "max";
    loader.timeout = 0;
    initrd.systemd.enable = true;
  };

  # Enable support SANE scanners
  hardware.sane.enable = true;

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
  ];


  environment.etc = {
    "prometheus_scripts/logged_in_users_exporter.sh" = {
      mode = "0555";
      text = ''
        #!/bin/bash
        OUTPUT_FILE="/var/lib/node_exporter/textfile_collector/logged_in_users.prom"
        > "$OUTPUT_FILE"
        loginctl list-sessions --no-legend | while read -r session_id uid user seat leader class tty idle since; do
          if [[ $class == "user" ]] && [[ $seat == "seat0" ]] && [[ $idle == "no" ]]; then
            state=$(loginctl show-session "$session_id" -p State --value)
            if [[ $state == "active" ]]; then
              locked_status="unlocked"
            else
              locked_status="locked"
            fi
          echo "node_logged_in_user{name=\"$user\", state=\"$locked_status\"} 1" > $OUTPUT_FILE
          fi
        done
      '';
    };
  };

  # Create the textfile collector directory
  systemd.tmpfiles.rules = [
    "d /var/lib/node_exporter/textfile_collector 0755 root root -"
    "d /etc/prometheus_scripts 0755 root root -"
    "z /etc/prometheus_scripts/logged_in_users_exporter.sh 0755 root root -"
  ];


  systemd.timers."logged_in_users_exporter" = {
    description = "Run logged_in_users_exporter.sh every 5 seconds";
    wantedBy = [ "multi-user.target" ];
    timerConfig = {
      OnBootSec = "5s";
      OnUnitActiveSec = "5s";
      Unit = "logged_in_users_exporter.service";
    };
  };

  systemd.services."logged_in_users_exporter" = {
    description = "Logged in users exporter";
    script = "bash /etc/prometheus_scripts/logged_in_users_exporter.sh";
    serviceConfig = {
      Environment = "PATH=/run/current-system/sw/bin";
      Type = "oneshot";
    };
    wantedBy = [ "multi-user.target" ];
  };

  services = {
    avahi.enable = true;

    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
    };

    prometheus = {
      exporters = {
        node = {
          enable = true;
          port = 9100;
          enabledCollectors = [ "systemd" "textfile" ];
          extraFlags = [ "--collector.ethtool" "--collector.softirqs" "--collector.tcpstat" "--collector.wifi" "--collector.textfile.directory=/var/lib/node_exporter/textfile_collector" ];
        };
      };
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
