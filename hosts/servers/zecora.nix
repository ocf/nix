{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "zecora";
  
  age.secrets.irc-passwd.rekeyFile = ../../secrets/master-keyed/irc-passwd.age;

  system.activationScripts."irc-passwd" = ''
    secret=$(cat "${config.age.secrets.irc-passwd.path}")
    configFile=/etc/ergo.yaml
    ${lib.getExe pkgs.gnused} -i "s/@irc-passwd@/$secret/g" "$configFile"
  '';

  ocf.network = {
    enable = true;
    lastOctet = 44;
  };

  services.ergochat = {
    enable = true;
    settings = {
      opers = {
        admin = {
	  password = "@irc-passwd@";
	};
      };
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
