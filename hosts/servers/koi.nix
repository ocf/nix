{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "koi";

  ocf.motd.description = ''
    Welcome to the new NixOS based staff login server!
      - install a package: nix profile add 'nixpkgs#package-name'
      - upgrade all packages: nix profile upgrade --all
      - ...or manage packages declaratively with home-manager!
      - packages can be searched at https://search.nixos.org

    You can still access the old login server if required at:
      supernova.ocf.berkeley.edu

    If you have any questions or concerns, contact us at:
      help@ocf.berkeley.edu;
    or ask on IRC (Halloy), Matrix, or Discord.
  '';

  ocf.network = {
    enable = true;
    lastOctet = 129;
  };

  ocf.loginServer.enable = true;

  age.secrets.ocfprinting = {
    rekeyFile = ../../secrets/master-keyed/ocfprinting.age;
    path = "/etc/ocfprinting.json";
    owner = "root";
    group = "ocfstaff";
    mode = "0640";
  };

  age.secrets.ocfweb-conf = {
    rekeyFile = ../../secrets/master-keyed/koi/ocfweb.conf.age;
    path = "/etc/ocfweb/ocfweb.conf";
    owner = "root";
    mode = "0644";
  };

  age.secrets.puppet-ca = {
    rekeyFile = ../../secrets/master-keyed/koi/puppet-ca.pem.age;
    path = "/etc/ocfweb/puppet-certs/puppet-ca.pem";
    owner = "root";
    mode = "0644";
  };

  age.secrets.puppet-cert = {
    rekeyFile = ../../secrets/master-keyed/koi/puppet-cert.pem.age;
    path = "/etc/ocfweb/puppet-certs/puppet-cert.pem";
    owner = "root";
    mode = "0644";
  };

  age.secrets.puppet-private = {
    rekeyFile = ../../secrets/master-keyed/koi/puppet-private.pem.age;
    path = "/etc/ocfweb/puppet-certs/puppet-private.pem";
    owner = "root";
    mode = "0600";
  };

  age.secrets.puppet-public = {
    rekeyFile = ../../secrets/master-keyed/koi/puppet-public.pem.age;
    path = "/etc/ocfweb/puppet-certs/puppet-public.pem";
    owner = "root";
    mode = "0644";
  };

  age.secrets.puppet-signed = {
    rekeyFile = ../../secrets/master-keyed/koi/puppet-signed.pem.age;
    path = "/etc/ocfweb/puppet-certs/puppet-signed.pem";
    owner = "root";
    mode = "0644";
  };

  system.stateVersion = "25.05";
}
