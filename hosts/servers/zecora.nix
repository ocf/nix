{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "zecora";

  ocf.network = {
    enable = true;
    lastOctet = 50;
  };

  services.ergochat = {
    enable = true;
    network.name = "OCF";
    server.name = "dev-irc.ocf.berkeley.edu";
  };

  ocf.acme.extraCerts = [ irc.ocf.io ];

  # make ssl certs visible to ircd user

  # enable SSL in ircd.conf

  system.stateVersion = "24.11";
}
