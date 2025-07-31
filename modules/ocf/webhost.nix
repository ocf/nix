{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.webhost;

  makeUsers = website-cfg: lib.mkIf website-cfg.enable {
    "deploy-${website-cfg.name}" = {
      group = "nginx";
      isNormalUser = true;
      createHome = false;
      openssh.authorizedKeys.keys = [
        "${website-cfg.githubActionsPubkey}"
      ];
    };
  };

  makeVirtHosts = website-cfg: lib.mkIf website-cfg.enable {
    "${website-cfg.name}.ocf.berkeley.edu" = {
      forceSSL = true;
      useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
      serverAliases = [ "${website-cfg.name}.ocf.io" ];
      root = "/var/www/${website-cfg.name}";
    };
  };

  defaultVirtHost =  [
    {
      default-server = {
        default = true;
        serverName = "_";
        forceSSL = true;
        useACMEHost = "${config.networking.hostName}.ocf.berkeley.edu";
        locations."/".return = 444;
      };
    }
  ];

  makeDirs = website-cfg:
    if website-cfg.enable then [ "d /var/www/${website-cfg.name} 775 deploy-${website-cfg.name} nginx" ]
    else [ ];


  makeExtraCerts = website-cfg:
    if website-cfg.enable then [ "${website-cfg.name}.ocf.berkeley.edu" "${website-cfg.name}.ocf.io" ]
    else [ ];

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
        };


      }
      );
    };
  };
  config = lib.mkIf cfg.enable {

    security.acme.certs."${config.networking.hostName}.ocf.berkeley.edu".group = "nginx";
    users.users = lib.mkMerge (builtins.map makeUsers cfg.websites);

    systemd.tmpfiles.rules = lib.flatten (builtins.map makeDirs cfg.websites);
    ocf.acme.extraCerts = lib.flatten (builtins.map makeExtraCerts cfg.websites);


    services.nginx = {
      enable = true;
      virtualHosts = lib.mkMerge ((builtins.map makeVirtHosts cfg.websites) ++ defaultVirtHost);
    };

  };
}
