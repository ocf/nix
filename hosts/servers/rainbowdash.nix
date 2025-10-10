{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "rainbowdash";

  ocf.network = {
    enable = true;
    lastOctet = 129;
  };

  ocf.nfs = {
    enable = true;
    mountHome = true;
    mountServices = true;
  };

  environment.systemPackages = with pkgs; [
    ipmitool
  ];

  system.stateVersion = "25.05";
}
