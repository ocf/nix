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
    # TODO: need ensure host keys can't be stolen by booting an external drive...
    acme.enable = false;

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
    remmina
    simple-scan

    # Cosmetics
    neofetch
    pfetch-rs

    # Default Hyprland Config
    hyprshot

  ];

  programs = {

    waybar = {
      enable = true;
    };

    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      plugins = [
        inputs.hyprland-plugins.packages."x86_64-linux".hyprbars
      ];

      settings = {
        "$mod" = "SUPER";
        exec-once = "waybar";
        monitor = [
          "DP-4, 2560x1440, 2560x0, 1"
          "HDMI-A-3, 2560x1440, 0x0, 1"
        ];
        general = {
          border_size = 2;
          gaps_in = 5;
          gaps_out = 20;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";

          # Set to true enable resizing windows by clicking and dragging on borders and gaps
          resize_on_border = false;

          # Please see https://wiki.hypr.land/Configuring/Tearing/ before you turn this on
          allow_tearing = false;

          layout = "dwindle";
        };
        decoration = {
          rounding = 10;
          rounding_power = 2;
          active_opacity = 1.0;
          inactive_opacity = 1.0;
          blur = {
            enabled = true;
            size = 8;
            passes = 3;
            noise = 0.01;
            brightness = 0.8;
          };
          shadow = {
            enabled = true;
            range = 8;
            render_power = 3;
            color = "rgba(00000044)";
          };
        };
        animations = {
          enabled = "yes, please :)";
        };
        misc = {
          disable_hyprland_logo = false;
          force_default_wallpaper = "-1";
        };

        bind = [

        # basics
        "$mod, C, killactive"
        "$mod, C, killactive"
        ", F11, fullscreen"

        # application shortcuts
        "$mod, Q, exec, kitty"
        "$mod, G, exec, firefox"

        # workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "SUPER_SHIFT, 1, movetoworkspace, 1"
        "SUPER_SHIFT, 2, movetoworkspace, 2"
        "SUPER_SHIFT, 3, movetoworkspace, 3"
        "SUPER_SHIFT, 4, movetoworkspace, 4"
        "SUPER_SHIFT, 5, movetoworkspace, 5"

        # screenshots (windows keybinds)
        ", Print, exec, hyprshot -m window -m active --clipboard-only" # entire screen
        "Alt, Print, exec, hyprshot -m window --clipboard-only" # active window
        "SUPER_SHIFT, S, exec, hyprshot -m region --clipboard-only" # select a region
        ];

        plugin.hyprbars = {
          bar_color = "rgb(2a2a2a)";
          bar_height = 28;
          col_text = "rgba(ffffffdd)";
          bar_text_size = 11;
          bar_text_font = "Ubuntu Nerd Font";

          bar_button_padding = 12;
          bar_padding = 10;
          hyprbars-button = [
            "rgb(2a2a2a), 20, , hyprctl dispatch killactive"
            "rgb(2a2a2a), 20, , hyprctl dispatch fullscreen 2"
            #"rgb(2a2a2a), 20, ━, xdotool windowunmap $(xdotool getactivewindow)"
          ];
        };
      };
    };

  };

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
