{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "amethyst";

  ocf.network = {
    enable = true;
    lastOctet = 50;
  };

  security.acme.certs."${config.networking.hostName}.ocf.berkeley.edu".group = "nginx";
  ocf.acme.extraCerts = [ "bestdocs.ocf.berkeley.edu" "bestdocs.ocf.io" ];

  users.users = {
    "deploy-bestdocs" = {
      group = "nginx";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPFUy5jvotIFajdAbwnqYAcMZMlwAxTZ3wPq44fmZ4v2"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/www/bestdocs 775 deploy-bestdocs nginx"
  ];

  services.nginx = {
    enable = true;
    virtualHosts."bestdocs.ocf.berkeley.edu" = {
      forceSSL = true;
      useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
      serverAliases = [ "bestdocs.ocf.io" ];
      root = "/var/www/bestdocs";
    };
  };

  system.stateVersion = "24.11";
}
