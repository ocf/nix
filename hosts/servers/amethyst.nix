{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "amethyst";

  ocf.network = {
    enable = true;
    lastOctet = 50;
  };

  users.users = {
    "deploy-bestdocs" = {
      group = "nginx";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPFUy5jvotIFajdAbwnqYAcMZMlwAxTZ3wPq44fmZ4v2"
      ];
    };
  };

  # TODO add SSH key for user nginx that workflow can use to deploy
  services.nginx = {
    enable = true;
    virtualHosts."bestdocs.ocf.berkeley.edu" = {
      forceSSL = true;
      enableACME = true;
      serverAliases = [ "bestdocs.ocf.io" ];
      root = "/var/www/bestdocs";
    };
  };

  system.stateVersion = "24.11";
}
