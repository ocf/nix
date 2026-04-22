{
  lib,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./cups.nix
    ./enforcer.nix
    ./monitor.nix
  ];

  options.ocf.printhost = {
    enable = lib.mkEnableOption "OCF print server";

    mysqlPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the MySQL password.";
    };

    wayoutPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the wayout notification password.";
    };

    redisPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Redis broker password.";
    };

    printhostUrl = lib.mkOption {
      type = lib.types.str;
      description = "Public hostname for the print server (used as CUPS ServerName and TLS cert name).";
      default = "printhost.ocf.berkeley.edu";
    };

    printerCerts = {
      printerUrls = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of printer FQDNs to generate TLS certificates for and automatically upload to the printers via their HP web interface.";
        default = [ ];
      };

      adminPasswordFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to file containing the HP printer admin password.";
      };
    };
  };

  config = lib.mkIf config.ocf.printhost.enable {
    # cups user needs acme group to read /var/lib/acme certs in preStart
    users.users."cups".extraGroups = [ "acme" ];
    # root needs lp group to run lpadmin in the printer setup service
    users.users."root".extraGroups = [ "lp" ];

    # Reload CUPS when the host's LE cert is renewed (cert lives at hostName path,
    # printhost SAN is included as an extraCert below)
    security.acme.certs."${config.networking.hostName}.ocf.berkeley.edu".reloadServices = [
      "cups.service"
    ];

    # Add printhostUrl, its .ocf.io variant, and all printer FQDNs as SANs
    ocf.acme.extraCerts =
      let
        cfg = config.ocf.printhost;
        certCfg = cfg.printerCerts;
        withIO = url: [
          url
          (lib.replaceStrings [ ".ocf.berkeley.edu" ] [ ".ocf.io" ] url)
        ];
      in
      lib.concatMap withIO ([ cfg.printhostUrl ] ++ certCfg.printerUrls);

    # After cert renewal, convert to PKCS12 and upload to each printer
    ocf.acme.postRun =
      let
        certCfg = config.ocf.printhost.printerCerts;
        certDir = "/var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu";
        uploadScript = printerUrl: ''
          umask 077
          pfx=$(mktemp /run/printer-cert-XXXXXX.pfx)
          trap 'rm -f "$pfx"' EXIT
          pass=$(${pkgs.openssl}/bin/openssl rand -base64 32)
          admin_pass=$(cat ${certCfg.adminPasswordFile})

          ${pkgs.openssl}/bin/openssl pkcs12 -export \
            -out "$pfx" \
            -inkey ${certDir}/key.pem \
            -in ${certDir}/cert.pem \
            -passout pass:"$pass"

          ${pkgs.curl}/bin/curl -v --insecure \
            -u admin:"$admin_pass" \
            -X PUT \
            -H "Content-Type: application/octet-stream" \
            -H "X-Certificate-Password: $pass" \
            --data-binary "@$pfx" \
            https://${printerUrl}/hp/device/Certificate.pfx
        '';
      in
      lib.mkIf (certCfg.printerUrls != [ ]) (
        lib.concatMapStringsSep "\n" uploadScript certCfg.printerUrls
      );
  };
}
