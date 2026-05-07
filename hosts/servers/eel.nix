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
    lastOctet = 97;
  };

  ocf.kerberosServer.enable = true;
  ocf.ldapServer.enable = true;

  ocf.acme.extraCerts = [
    "ldap.ocf.berkeley.edu"
    "kerberos.ocf.berkeley.edu"
  ];

  system.stateVersion = "25.11";
}
