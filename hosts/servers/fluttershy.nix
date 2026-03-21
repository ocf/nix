{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "fluttershy";

  ocf.network = {
    enable = true;
    lastOctet = 130;
  };

  ocf.nfs = {
    enable = true;
    mountHome = true;
    mountServices = true;
  };

  environment.systemPackages = with pkgs; [
    ocf-utils
    openldap
    ldapvi
    ipmitool
  ];

  system.stateVersion = "25.05";
}
