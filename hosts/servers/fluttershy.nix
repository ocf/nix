{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  # tsunami replacement host

  networking.hostName = "fluttershy";

  ocf.network = {
    enable = true;
    lastOctet = 130;
  };

  ocf.ssh.enable = true;

  ocf.nfs = {
    enable = true;
    mountHome = true;
    mountServices = true;
  };

  system.stateVersion = "25.05";
}
