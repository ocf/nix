{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.webhost;
  baseDomain = "ocf.berkeley.edu";
  shortDomain = "ocf.io";
  fqdn = "${config.networking.hostName}.${baseDomain}";

  enabledSites = builtins.filter (website-cfg: website-cfg.enable) cfg.websites;

  makeUsers = website-cfg: {
    "deploy-${website-cfg.name}" = {
      group = "nginx";
      isNormalUser = true;
      createHome = false;
      openssh.authorizedKeys.keys = [
        "${website-cfg.githubActionsPubkey}"
      ];
    };
  };

  makeVirtHosts = website-cfg: {
    "${website-cfg.name}.${baseDomain}" = {
      forceSSL = true;
      useACMEHost = "${fqdn}";
      serverAliases = [ "${website-cfg.name}.${shortDomain}" ];
      root = "/var/www/${website-cfg.name}";
      extraConfig = ''
      	add_header Cache-Control "public, max-age=${website-cfg.cacheTime}";
	'';
    };
  };

  defaultVirtHost = [
    {
      default-server = {
        default = true;
        serverName = "_";
        forceSSL = true;
        useACMEHost = "${fqdn}";
        locations."/".return = 444;
      };
    }
  ];

  makeTmpFileRules = website-cfg: {
    "/var/www/${website-cfg.name}" = {
      d = {
        mode = "0775";
        user = "deploy-${website-cfg.name}";
        group = "nginx";
      };
    };
  };


  makeExtraCerts = website-cfg: [
    "${website-cfg.name}.${baseDomain}"
    "${website-cfg.name}.${shortDomain}"
  ];

in
{
  options.ocf.webhost = {
    enable = lib.mkEnableOption "Enable static webhosting configuration";
    websites = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {


        options = {
          enable = lib.mkEnableOption "Enable this website";

          name = lib.mkOption {
            type = lib.types.str;
            description = "Subdomain of webpage - will set <name>.ocf.berkeley.edu & <name>.ocf.io";
          };

          githubActionsPubkey = lib.mkOption {
            type = lib.types.str;
            description = "SSH Public Key of Github Actions Deploy Workflow";
          };
	  # For some reason Nginx on our nix servers doesn't update the Last Modified header, 
	  # which leads to content being cached indefinetely.
	  cacheTime = lib.mkOption {
	    type = lib.types.str;
	    description = "Browser file cache time in seconds";
	    default = "3600";
	  };
        };


      }
      );
    };
  };
  config = lib.mkIf cfg.enable {

    security.acme.certs."${fqdn}".group = "nginx";
    users.users = lib.mkMerge (builtins.map makeUsers enabledSites);
    systemd.tmpfiles.settings."web-roots" = lib.mkMerge (builtins.map makeTmpFileRules enabledSites);
    ocf.acme.extraCerts = (builtins.concatMap makeExtraCerts enabledSites);


    services.nginx = {
      enable = true;
      virtualHosts = lib.mkMerge (
        (builtins.map makeVirtHosts enabledSites)
        ++ defaultVirtHost
      );
    };

  };
}
