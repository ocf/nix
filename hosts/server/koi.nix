{
  pkgs,
  lib,
  config,
  ...
}:

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

  age.secrets =
    let
      secrets = [
        {
          name = "ocfprinting";
          rekeyFile = ../../secrets/master-keyed/ocfprinting.age;
          path = "/etc/ocfprinting.json";
        }
        # like puppet certs, needed for the ocfmail-dev and ocfstats-dev users that are in the ocfweb tests suite, which is run on koi.
        {
          name = "ocfweb-conf";
          rekeyFile = ../../secrets/master-keyed/koi/ocfweb.conf.age;
          path = "/etc/ocfweb/ocfweb.conf";
        }
        {
          name = "ucbldap";
          rekeyFile = ../../secrets/master-keyed/koi/ucbldap.passwd.age;
          path = "/etc/ucbldap.passwd";
        }
      ];
      # These puppet certs are necessary to (at least) load the servers page properly in the dev environment on ocfweb. The puppetdb must be queried by koi when running ocfweb tests to get correct information about puppet hosts (ex. which ones are kvm hypervisors, what are their corresponding VMs)
      puppetSecretTypes = [
        "ca"
        "cert"
        "private"
        "public"
        "signed"
      ];
    in
    # build age.secrets.${secret.name} from secrets
    builtins.listToAttrs
    ++ (map (secret: {
      inherit (secret) name;
      value = {
        inherit (secret) rekeyFile path;
        owner = "root";
        group = "ocfstaff";
        mode = "0640";
      };
    }) secrets)
    # build age.secrets.puppet-${type} from puppetSecretTypes
    ++ (map (type: {
      name = "puppet-${type}";
      value = {
        rekeyFile = ../../secrets/master-keyed/koi/puppet-${type}.pem.age;
        path = "/etc/ocfweb/puppet-certs/puppet-${type}.pem";
        owner = "root";
        mode = "0644";
      };
    }) puppetSecretTypes);

  system.stateVersion = "25.05";
}
