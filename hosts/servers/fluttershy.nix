{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  # tsunami replacement host

  networking.hostName = "fluttershy";

  ocf.network = {
    enable = true;
    lastOctet = 130;
  };

  # staff-only while wip
  #ocf.auth.extra_access_conf = [ "+:(ocf):ALL" "+:(sorry):ALL" ];

  ocf.nfs = {
    enable = true;
    mountHome = true;
    mountServices = true;
  };

  system.stateVersion = "25.05";
}
