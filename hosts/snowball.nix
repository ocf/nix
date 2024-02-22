{ config, pkgs, ... }:

{
  imports = [
    ../hardware/ridge-test-pc.nix
  ];

  networking.hostName = "snowball";

  ocf = {
    auth.enable = true;
    desktop.enable = true;

    network = {
      enable = true;
      interface = "enp8s0";
      lastOctet = 99;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}