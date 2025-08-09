{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "scootaloo";
  
  ocf.network = {
    enable = true;
    lastOctet = 29;
  };

  ocf.acme.extraCerts = [ "matrix.ocf.berkeley.edu" "matrix.ocf.io" ];

  ocf.synapse = {
    enable = true;
    postgresPackage = pkgs.postgresql_16;
    baseUrl = "matrix.ocf.io";
    serverName = "ocf.io";
  };

  system.stateVersion = "25.05";
}
