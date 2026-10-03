{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.webhost;
  baseDomain = "ocf.berkeley.edu";
  shortDomain = "ocf.io";
  fqdn = "${config.networking.hostName}.${baseDomain}";

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
                add_header Last-Modified "";
              	add_header Cache-Control "public, max-age=${website-cfg.cacheTime}";
        	'';
    };
  };

  makeRedirectVirtHosts = redirect-cfg: {
    "${redirect-cfg.name}.${baseDomain}" = {
      forceSSL = true;
      useACMEHost = "${fqdn}";
      serverAliases = [ "${redirect-cfg.name}.${shortDomain}" ];
      globalRedirect = "${redirect-cfg.target}.${baseDomain}";
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
    enable = lib.mkEnableOption "static webhosting configuration";
    websites = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {

          options = {
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
    redirects = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {

          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Subdomain to redirect from - will redirect <name>.ocf.berkeley.edu & <name>.ocf.io";
            };

            target = lib.mkOption {
              type = lib.types.str;
              description = "Subdomain to redirect to - will redirect to <target>.ocf.berkeley.edu";
            };
          };

        }
      );
    };
  };
  config = lib.mkIf cfg.enable {

    security.acme.certs."${fqdn}".group = "nginx";
    users.users = lib.mkMerge (builtins.map makeUsers cfg.websites);
    systemd.tmpfiles.settings."web-roots" = lib.mkMerge (builtins.map makeTmpFileRules cfg.redirects);
    ocf.acme.extraCerts = builtins.concatMap makeExtraCerts (cfg.websites ++ cfg.redirects);

    services.nginx = {
      enable = true;
      virtualHosts = lib.mkMerge (
        (builtins.map makeVirtHosts cfg.websites)
        ++ (builtins.map makeRedirectVirtHosts cfg.redirects)
        ++ defaultVirtHost
      );
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
  };
}
