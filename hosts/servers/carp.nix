{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "carp";

  ocf.motd.description = ''
    Welcome to the new NixOS based public login server!
      - install a package: nix profile add 'nixpkgs#package-name'
      - upgrade all packages: nix profile upgrade --all
      - ...or manage packages declaratively with home-manager!
      - packages can be searched at https://search.nixos.org

    You can still access the old login server if required at:
      tsunami.ocf.berkeley.edu

    If you have any questions or concerns, contact us at:
      help@ocf.berkeley.edu;
    or ask on IRC (Halloy), Matrix, or Discord.
  '';

  ocf.network = {
    enable = true;
    lastOctet = 130;
  };

  ocf.loginServer = {
    enable = true;
    public = true;
  };

  # this should be in ocf utils package somehow
  security.sudo.extraConfig = ''
    ALL ALL=(mysql) NOPASSWD: /run/current-system/sw/bin/makemysql-real
  '';

  age.secrets.makemysql-conf = {
    rekeyFile = ../../secrets/master-keyed/carp/makemysql.conf.age;
    path = "/opt/share/makeservices/makemysql.conf";
    owner = "mysql";
    group = "root";
    mode = "0400";
  };

  system.stateVersion = "25.05";
}
