{ ... }:

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

  ocf.login-server = {
    enable = true;
    ttyd = true;
  };

  security.pam.loginLimits = [
    {
      domain = "@ocf";
      type = "soft";
      item = "cpu";
      value = "60";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "cpu";
      value = "1440";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "stack";
      value = "4096";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "core";
      value = "0";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "nproc";
      value = "250";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "nofile";
      value = "1024";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "memlock";
      value = "2047219";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "as";
      value = "12000000";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "sigpending";
      value = "63810";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "msgqueue";
      value = "819200";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "nice";
      value = "0";
    }
    {
      domain = "@ocf";
      type = "hard";
      item = "rtprio";
      value = "0";
    }
  ];

  system.stateVersion = "25.05";
}
