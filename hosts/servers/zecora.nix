{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "zecora";
  # TODO: Move IRC related config into a custom OCF module

  ocf.network = {
    enable = true;
    lastOctet = 44;
  };

  ocf.irc = {
    enable = true;
  };

  system.stateVersion = "24.11";
}
