{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "zecora";

  ocf.network = {
    enable = true;
    lastOctet = 44;
  };

  services.ergochat = {
    enable = true;
    settings.network.name = "OCF";
    settings.server.name = "dev-irc.ocf.berkeley.edu";
  };

  ocf.acme.extraCerts = [ "dev-irc.ocf.berkeley.edu" "dev-irc.ocf.io" ];

  # make ssl certs visible to ircd user

  # enable SSL in ircd.conf

  system.stateVersion = "24.11";
}
