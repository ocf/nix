{ ... }:

{
  imports = [
    ../../hardware/snowball.nix
    ../../profiles/desktop.nix
  ];

  networking.hostName = "snowball";

  ocf.nvidia.enable = true;
  ocf.network = {
    enable = true;
    # DNS lookup returns 99 but not sure why, was supposed to be configured as 140
    # 140 has now been assigned to ./melange.nix
    # TODO: Figure out what happend to snowball...
    lastOctet = 99;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
