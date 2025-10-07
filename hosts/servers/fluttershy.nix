{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  # tsunami replacement host

  networking.hostName = "fluttershy";

  ocf.network = {
    enable = true;
    lastOctet = 130;
  };

  ocf.auth.extra_access_conf = [ "+:(ocf):ALL" "+:(sorry):ALL" ];

  system.stateVersion = "25.05";
}
