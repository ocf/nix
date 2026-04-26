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

  ocf.managed-deployment.staffOnlySsh = false;

  ocf.ttyd.enable = true;
  ocf.etc.enable = true;
  ocf.userPackages.enable = true;

  ocf.nfs = {
    enable = true;
    mount = true;
  };

  environment.systemPackages = with pkgs; [
    ocf-utils
    openldap
    ldapvi
    ipmitool
  ];

  services.openssh.settings = {
    PasswordAuthentication = true;
    LoginGraceTime = 30;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
  };

  services.fail2ban = {
    enable = true;
    jails.sshd.settings = {
      enabled = true;
      maxretry = 5;
    };
  };

  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "cpu";
      value = "60";
    }
    {
      domain = "*";
      type = "soft";
      item = "stack";
      value = "4096";
    }
    {
      domain = "*";
      type = "soft";
      item = "core";
      value = "0";
    }
    {
      domain = "*";
      type = "soft";
      item = "nproc";
      value = "250";
    }
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "1024";
    }
    {
      domain = "*";
      type = "-";
      item = "memlock";
      value = "2047219";
    }
    {
      domain = "*";
      type = "-";
      item = "as";
      value = "12000000";
    }
    {
      domain = "*";
      type = "soft";
      item = "sigpending";
      value = "63810";
    }
    {
      domain = "*";
      type = "soft";
      item = "msgqueue";
      value = "819200";
    }
    {
      domain = "*";
      type = "soft";
      item = "nice";
      value = "0";
    }
    {
      domain = "*";
      type = "soft";
      item = "rtprio";
      value = "0";
    }
  ];

  age.secrets.makemysql-conf = {
    rekeyFile = ../../secrets/master-keyed/carp/makemysql.conf.age;
    path = "/opt/share/makeservices/makemysql.conf";
    owner = "mysql";
    group = "root";
    mode = "0400";
  };

  system.stateVersion = "25.05";
}
