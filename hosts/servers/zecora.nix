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
    settings = {
      network.name = "OCF";
      server = {
         name = "dev-irc.ocf.berkeley.edu";
	 sts.enabled = true;
      };
    };
  };

  ocf.acme.extraCerts = [ "dev-irc.ocf.berkeley.edu" "dev-irc.ocf.io" ];

  security.acme.certs."dev-irc.ocf.berkeley.edu".group = "ergochat";
  security.acme.certs."dev-irc.ocf.berkeley.edu".user = "ergochat";
  users.users."ergo" {
    createHome = true;
  };

  system.ActivationScripts = {
    link-ergochat-certs = {
    text =
      ''
        ln -sfn /var/lib/acme/zecora.ocf.berkeley.edu/fullchain.pem /home/ergo/fullchain.pem
        ln -sfn /var/lib/acme/zecora.ocf.berkeley.edu/key.pem /home/ergo/privkey.pem
      '';
    };
  };

  system.stateVersion = "24.11";
}
