{ pkgs, lib, inputs, ... }:

{
  nix = {
    channel.enable = false;
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;
    settings = {
      experimental-features = "nix-command flakes";
      nix-path = lib.mapAttrsToList (name: _: "${name}=flake:${name}") inputs;
    };
  };

  ocf = {
    auth.enable = lib.mkDefault true;
    shell.enable = lib.mkDefault true;
  };

  boot.loader = {
    systemd-boot = {
      enable = lib.mkDefault true;
      consoleMode = "max";
    };

    grub.enable = lib.mkDefault false;
    efi.canTouchEfiVariables = true;
  };

  security.pam = {
    services.login.makeHomeDir = true;
    services.sshd.makeHomeDir = true;
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Temporary, make dedicated deploy user later
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGlViRB5HH1bTaS1S7TcqVBSuxKdrbdhL2CmhDqc/t6A" # oliverni
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiiq/rSfG+bKmqKZfCSl1z2r7rc3Wt/Paya/JYmjdSO" # njha
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHC9Yh1qdHa9rq28Ki0i53vtHgg9ksKq8vg9M+9GGPA5" # etw
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOssvEhZ5BG96yH4fsjYhY6xKt3AKyuyAD5TXapdQUw" # lemurseven
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOaJJvOUG08qr3yeeQRB71M30cdPMuO69nsf0CodALa" # jaysa
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPeJeRNwcPaZupbmCEtUIOuLDfhow35byMp548TUDYP" # rjz
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6zftyMUeIQVYkRag6CxWqYShjWnErQ24NeaU95Bp2z" # laksith
  ];

  programs.ssh = {
    package = pkgs.openssh_gssapi;
    extraConfig = ''
      CanonicalizeHostname yes
      CanonicalDomains ocf.berkeley.edu
      Host *.ocf.berkeley.edu *.ocf.io 169.229.226.* 2607:f140:8801::*
          GSSAPIAuthentication yes
          GSSAPIKeyExchange yes
          GSSAPIDelegateCredentials no
    '';
  };

  environment.systemPackages = with pkgs; [
    # System utilities
    dnsutils
    # This doesn't work on aarch64 for some reason
    # cpufrequtils
    pulseaudio
    pciutils
    usbutils
    cups
    ipmitool
    smartmontools
    nvme-cli

    # Networking tools
    rsync
    wget
    curl

    # Other useful stuff
    tmux
    htop
    file
    vim
    git
    killall

    comma-with-db
  ];

  services = {
    openssh = {
      enable = true;
      settings.X11Forwarding = true;
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
    };

    envfs = {
      enable = true;

      # We need /bin/bash etc. to work because people's shells are set to it
      extraFallbackPathCommands = ''
        ln -s ${lib.getExe pkgs.bash} $out/bash
        ln -s ${lib.getExe pkgs.zsh} $out/zsh
        ln -s ${lib.getExe pkgs.fish} $out/fish
        ln -s ${lib.getExe pkgs.xonsh} $out/xonsh
      '';
    };

    fwupd.enable = true;
    avahi.enable = true;
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
  hardware.pulseaudio.enable = false;

  networking.firewall.enable = false;

  environment.etc = {
    papersize.text = "letter";
    "cups/lpoptions".text = "Default double";
    "cups/client.conf".text = ''
      ServerName printhost.ocf.berkeley.edu
      Encryption Always
    '';
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

  environment.etc."nixos/configuration.nix".text = ''
    {}: builtins.abort "This machine is not managed by /etc/nixos. Please use colmena instead."
  '';

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
}
