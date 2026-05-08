{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "eel";

  ocf.network = {
    enable = true;
    lastOctet = 98;
  };

  ocf.kerberosKdc.enable = true;
  ocf.ldapServer.enable = true;

  ocf.acme.extraCerts = [
    "eel-ldap.ocf.berkeley.edu"
    "eel-kerberos.ocf.berkeley.edu"
  ];

  system.stateVersion = "25.11";
}
