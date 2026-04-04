{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "koi";

  ocf.network = {
    enable = true;
    lastOctet = 129;
  };

  ocf.nfs = {
    enable = true;
    mountHome = true;
    mountServices = true;
  };

  age.secrets.ocfprinting = {
    rekeyFile = ../../secrets/master-keyed/ocfprinting.age;
    path = "/etc/ocfprinting.json";
    owner = "root";
    group = "ocfstaff";
    mode = "0640";
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
