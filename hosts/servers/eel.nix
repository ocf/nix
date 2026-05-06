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

  # Cert covers both service names as SANs so ldaps:// and kerberos clients
  # connecting to ldap.ocf.berkeley.edu / kerberos.ocf.berkeley.edu are happy
  ocf.acme.extraCerts = [
    "ldap.ocf.berkeley.edu"
    "kerberos.ocf.berkeley.edu"
  ];

  system.stateVersion = "25.11";
}
