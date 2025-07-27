{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "amethyst";

  ocf.network = {
    enable = true;
    lastOctet = 50;
  };

  # TODO add SSH key for user nginx that workflow can use to deploy
  services.nginx = {
    enable = true;
    virtualHosts."bestdocs.ocf.berkeley.edu" {
      addSSL = true;
      forceSSL = true;
      enableACME = true;
      serverAliases = [ "bestdocs.ocf.io" ];
      root = "/var/www/bestdocs";
    };
  };

  system.stateVersion = "24.11";
}
