{ ... }:

{
  imports = [
    ../hardware/raspberry-pi-4b.nix
  ];

  networking.hostName = "overheat";

  boot.loader = {
    systemd-boot.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  ocf = {
    auth.enable = true;

    network = {
      enable = true;
      lastOctet = 94;
    };

    kiosk = {
      enable = true;
      url = "https://printlist.ocf.berkeley.edu/home";
      wlrRandrOptions = "--output Unknown-1 --transform 270";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
