{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.webhost;
in
{
  options.ocf.webhost = {
    enable = lib.mkEnableOption "Enable static webhosting configuration";
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain of webpage - will set <subdomain>.ocf.berkeley.edu & <subdomain>.ocf.io";
    };
    githubActionsPubkey = lib.mkOption {
      type = lib.types.str;
      description = "SSH Public Key of Github Actions Deploy Workflow";
    };
  };

  config = lib.mkIf cfg.enable {
    security.acme.certs."${config.networking.hostName}.ocf.berkeley.edu".group = "nginx";
    ocf.acme.extraCerts = [ "${cfg.subdomain}.ocf.berkeley.edu" "${cfg.subdomain}.ocf.io" ];

    users.users = {
      "deploy-${cfg.subdomain}" = {
        group = "nginx";
	isNormalUser = true;
	openssh.authorizedKeys.keys = [
	  "${cfg.githubActionsPubkey}"
	];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/www/${cfg.subdomain} 775 deploy-${cfg.subdomain} nginx"
    ];

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.subdomain}.ocf.berkeley.edu" = {
        forceSSL = true;
	useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
	serverAliases = [ "${cfg.subdomain}.ocf.io" ];
	root = "/var/www/${cfg.subdomain}";
      };
    };

  };
}
