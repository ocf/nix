{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "scootaloo";
  
  ocf.network = {
    enable = true;
    lastOctet = 29;
  };

  ocf.acme.extraCerts = [ "matrix.ocf.berkeley.edu" "matrix.ocf.io" "chat.ocf.berkeley.edu" "chat.ocf.io" ];

  ocf.matrix = {
    enable = true;
    postgresPackage = pkgs.postgresql_16;
    baseUrl = "matrix.ocf.io";
    serverName = "ocf.io";

    discord.enable = true;

    element.enable = true;
    element.url = "chat.ocf.berkeley.edu";
  };

  system.stateVersion = "25.05";
}
