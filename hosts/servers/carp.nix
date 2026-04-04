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

  programs.ssh.extraConfig = lib.mkOverride 90 ''
    GSSAPIAuthentication yes
    GSSAPIKeyExchange yes
    GSSAPICleanupCredentials yes
    GSSAPIStrictAcceptorCheck yes
  '';

  system.stateVersion = "25.05";
}
