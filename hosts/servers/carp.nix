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

  ocf.ttyd.enable = true;

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

  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "cpu";        value = "3600"; }
    { domain = "*"; type = "soft"; item = "stack";      value = "4096"; }
    { domain = "*"; type = "soft"; item = "core";       value = "0"; }
    { domain = "*"; type = "soft"; item = "nproc";      value = "250"; }
    { domain = "*"; type = "soft"; item = "nofile";     value = "1024"; }
    { domain = "*"; type = "soft"; item = "memlock";    value = "2047219"; }
    { domain = "*"; type = "soft"; item = "as";         value = "12000000"; }
    { domain = "*"; type = "soft"; item = "sigpending"; value = "63810"; }
    { domain = "*"; type = "soft"; item = "msgqueue";   value = "819200"; }
    { domain = "*"; type = "soft"; item = "nice";       value = "0"; }
    { domain = "*"; type = "soft"; item = "rtprio";     value = "0"; }
  ];

  system.stateVersion = "25.05";
}
