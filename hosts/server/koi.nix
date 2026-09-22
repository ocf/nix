{
  pkgs,
  lib,
  config,
  ...
}:

let
  # age.secrets.${name}
  secrets = {
    ocfprinting = {
      rekeyFile = ../../secrets/master-keyed/ocfprinting.age;
      path = "/etc/ocfprinting.json";
    };
    # like puppet certs, needed for the ocfmail-dev and ocfstats-dev users that are in the ocfweb tests suite, which is run on koi.
    ocfweb-conf = {
      rekeyFile = ../../secrets/master-keyed/koi/ocfweb.conf.age;
      path = "/etc/ocfweb/ocfweb.conf";
    };
    ucbldap = {
      rekeyFile = ../../secrets/master-keyed/koi/ucbldap.passwd.age;
      path = "/etc/ucbldap.passwd";
    };
  };

  makeSecret = name: value: {
    inherit (value) rekeyFile path;
    owner = "root";
    group = "ocfstaff";
    mode = "0640";
  };

  # These puppet certs are necessary to (at least) load the servers page properly in the dev environment on ocfweb. The puppetdb must be queried by koi when running ocfweb tests to get correct information about puppet hosts (ex. which ones are kvm hypervisors, what are their corresponding VMs)

  # get puppet secrets from filenames (e.g. "puppet-ca")
  puppetSecrets = map (s: lib.removeSuffix ".pem.age" s) (
    lib.filter (lib.hasPrefix "puppet-") (lib.attrNames (lib.readDir ../../secrets/master-keyed/koi))
  );

  makePuppetSecret = puppetType: {
    rekeyFile = ../../secrets/master-keyed/koi/${puppetType}.pem.age;
    path = "/etc/ocfweb/puppet-certs/${puppetType}.pem";
    owner = "root";
    mode = "0644";
  };
in
{
  imports = [ ../../hardware/virtualized.nix ];

  ocf.motd.description = ''
    Welcome to the new NixOS based staff login and development server!
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

  age.secrets = builtins.mapAttrs makeSecret secrets // lib.genAttrs puppetSecrets makePuppetSecret;

  system.stateVersion = "25.05";
}
