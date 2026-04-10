{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "carp";

  ocf.network = {
    enable = true;
    lastOctet = 130;
  };

  ocf.wetty.enable = true;

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
