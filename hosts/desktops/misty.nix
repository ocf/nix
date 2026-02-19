{ ... }:

{
  imports = [
    ../../hardware/ridge-pc.nix
    ../../profiles/desktop.nix
  ];

  networking.hostName = "misty";

  ocf.nvidia = {
    enable = true;
    open = false;
  };

  ocf.network = {
    enable = true;
    lastOctet = 156;
  };

  ocf.managed-deployment.mac-address = "9c:6b:00:38:7f:70";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
