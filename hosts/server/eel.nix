{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "eel";

  ocf.motd.description = ''
    LDAP and Kerberos server; crucial to the rest of our infrastucture working.
  '';

  ocf.network = {
    enable = true;
    lastOctet = 98;
  };

  ocf.kerberosKdc.enable = true;
  ocf.ldapServer.enable = true;

  ocf.acme.extraCerts = [
    "ldap0.ocf.berkeley.edu"
    "kdc.ocf.berkeley.edu"
  ];

  system.stateVersion = "25.11";
}
