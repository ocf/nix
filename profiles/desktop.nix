{ pkgs, lib, inputs, ... }:

# TODO: Move this to pkgs/ or come up with a better way to manage custom scripts
let
  vncScript = pkgs.writeShellScriptBin "ocf-tv" ''
    ${lib.getExe pkgs.openssh_gssapi} -M -S /tmp/ocftv-ssh-ctl -fNT -L 5900:localhost:5900 tornado
    ${lib.getExe pkgs.remmina} --no-tray-icon --disable-news --disable-stats --enable-extra-hardening -c vnc://localhost
    ${lib.getExe pkgs.openssh_gssapi} -S /tmp/ocftv-ssh-ctl -O exit tornado
  '';
  # override ocf-tv from util
  ocf-tv = pkgs.hiPrio vncScript;
in
{

  # Colmena tagging
  deployment.tags = [ "desktop" ];

  ocf = {
    etc.enable = true;
    graphical.enable = true;
    browsers.enable = true;
    tmpfsHome.enable = true;
    network.wakeOnLan.enable = true;
  };

  boot.loader.systemd-boot.consoleMode = "max";

  # Enable support SANE scanners
  hardware.sane.enable = true;

  environment.systemPackages = with pkgs; [
    # Editors
    emacs
    neovim
    helix
    kakoune

    # Languages
    (python312.withPackages (ps: [ ps.ocflib ]))
    poetry
    ruby
    elixir
    clojure
    ghc
    rustup
    clang
    nodejs_22

    # File management tools
    zip
    unzip
    _7zz
    eza
    tree
    dua
    bat

    # Other tools
    ocf-utils
    bar
    tmux
    s-tui
    ocf-tv

    # Cosmetics
    neofetch
    pfetch-rs
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

  # Needed for generic Linux programs
  # More info: https://nix.dev/guides/faq#how-to-run-non-nix-executables
  programs.nix-ld.enable = true;
}
