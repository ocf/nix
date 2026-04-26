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

  ocf.etc.enable = true;
  ocf.userPackages.enable = true;

  services.openssh.settings = {
    PasswordAuthentication = true;
    LoginGraceTime = 30;
  };

  networking.firewall.enable = true;

  services.fail2ban = {
    enable = true;
    jails.sshd.settings = {
      enabled = true;
      maxretry = 5;
    };
  };

  ocf.nfs = {
    enable = true;
    mount = true;
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

  system.stateVersion = "25.05";
}
