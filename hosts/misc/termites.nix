{ config, pkgs, ... }:

{
  imports = [
    ../../hardware/termites.nix
  ];

  networking.hostName = "termites";

  fileSystems."/home" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=16G" "mode=755" ];
  };

  ocf = {
    auth.enable = true;

    network = {
      enable = true;
      lastOctet = 95;
    };

    kiosk = {
      enable = true;
      url = "https://ocf.berkeley.edu";
      extraConfig = ''
        output Unknown-1 {
          mode 2560x1440@60Hz
          scale 1.5
        }
      '';
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.1"; # Did you read the comment?
}
