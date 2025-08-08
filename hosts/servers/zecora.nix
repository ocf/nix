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
      opers = "jaysa";
      network.name = "OCF";
      server = {
        name = "dev-irc.ocf.berkeley.edu";
        sts.enabled = true;
	listeners.":6697".tls = {
	  cert = "/var/lib/acme/zecora.ocf.berkeley.edu/fullchain.pem";
	  key = "/var/lib/acme/zecora.ocf.berkeley.edu/key.pem";
	};
      };
    };
  };

  ocf.acme.extraCerts = [ "dev-irc.ocf.berkeley.edu" "dev-irc.ocf.io" ];

  users.users."ergochat" = {
    isNormalUser = true;
    createHome = true;
    group = "acme";
  };

  system.stateVersion = "24.11";
}
