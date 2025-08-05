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
	listeners.":6697".tls = {
	  cert = "/home/ergochat/fullchain.pem";
	  key = "/home/ergochat/privkey.pem";
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

  system.activationScripts = {
    link-ergochat-certs = {
      text =
        ''
          ln -sfn /var/lib/acme/zecora.ocf.berkeley.edu/fullchain.pem /home/ergochat/fullchain.pem
          ln -sfn /var/lib/acme/zecora.ocf.berkeley.edu/key.pem /home/ergochat/privkey.pem
        '';
    };
  };

  system.stateVersion = "24.11";
}
