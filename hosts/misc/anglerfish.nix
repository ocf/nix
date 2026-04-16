{ pkgs, lib, ... }:

{
  imports = [
    ../../hardware/system76-meerkat.nix
  ];

  networking.hostName = "anglerfish";

  ocf = {
    auth.enable = true;
    graphical.apps.browsers.enable = true;

    network = {
      enable = true;
      lastOctet = 106;
    };

    jukebox = {
      enable = true;
      port = 6767;
      musicDir = "/run/jukebox-music";
    };

    graphical.kiosk = {
      enable = true;
      url = "https://labmap.ocf.berkeley.edu";
      extraConfig = ''
        output HDMI-A-1 {
          mode 3840x2160@60Hz
          scale 2
        }
      '';
    };
  };

  fonts.packages = [ pkgs.helvetica-neue-lt-std ];

  security.rtkit.enable = true;

  services = {
    mpd = {
      enable = true;
      network.port = 6600;
      network.listenAddress = "0.0.0.0";
      extraConfig = ''
        audio_output {
          type		"pulse"
          name		"Local Music Player Daemon"
          server		"127.0.0.1"
        }
      '';
    };

    avahi.publish = {
      enable = true;
      userServices = true;
      domain = true;
      addresses = true;
      hinfo = true;
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      extraConfig.pipewire-pulse."100-network-audio-sink"."pulse.cmd" = [
        {
          cmd = "load-module";
          args = "module-native-protocol-tcp auth-ip-acl=169.229.226.0/24 auth-anonymous=1";
        }
        {
          cmd = "load-module";
          args = "module-zeroconf-publish";
        }
      ];
    };
  };

  systemd.user.services = {
    pipewire.wantedBy = [ "default.target" ];
    pipewire-pulse.wantedBy = [ "default.target" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11";
}
