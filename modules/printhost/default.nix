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
          set -euo pipefail

          jar=$(${pkgs.coreutils}/bin/mktemp)
          pfx=$(${pkgs.coreutils}/bin/mktemp)
          # trap 'rm -f "$jar" "$pfx"' EXIT

          admin_pass=$(< ${certCfg.adminPasswordFile})
          pfx_pass=test

          ${pkgs.openssl}/bin/openssl pkcs12 -export \
            -out "$pfx" \
            -inkey ${certDir}/key.pem \
            -in ${certDir}/cert.pem \
            -certfile ${certDir}/chain.pem \
            -legacy \
            -keypbe PBE-SHA1-3DES \
            -certpbe PBE-SHA1-3DES \
            -macalg SHA1 \
            -passout pass:"$pfx_pass"

          CURL="${pkgs.curl}/bin/curl --fail-with-body -sS -k -b $jar -c $jar"

          # 1. Get sign-in page, scrape its CSRF token
          signin_page=$($CURL https://${printerUrl}/hp/device/SignIn/Index)
          signin_csrf=$(printf '%s' "$signin_page" \
            | ${pkgs.gnugrep}/bin/grep -oP 'name="CSRFToken" value="\K[^"]+' \
            | ${pkgs.coreutils}/bin/head -n1)

          # 2. Sign in
          $CURL -X POST https://${printerUrl}/hp/device/SignIn/Index \
            --data-urlencode "CSRFToken=$signin_csrf" \
            --data-urlencode "PasswordTextBox=$admin_pass" \
            --data-urlencode "signInOk=Sign In" \
            -o /dev/null

          # 3. Get certificates page (now authenticated) for upload CSRF + current cert ID
          cert_page=$($CURL https://${printerUrl}/hp/device/CertificatesTabs/Index)
          upload_csrf=$(printf '%s' "$cert_page" \
            | ${pkgs.gnugrep}/bin/grep -oP 'name="CSRFToken" value="\K[^"]+' \
            | ${pkgs.coreutils}/bin/head -n1)
          cert_id=$(printf '%s' "$cert_page" \
            | ${pkgs.gnugrep}/bin/grep -oP 'value="ID\|[A-F0-9]+"' \
            | ${pkgs.coreutils}/bin/head -n1 \
            | ${pkgs.gnused}/bin/sed 's/^value="//; s/"$//')

          if [ -z "$upload_csrf" ] || [ -z "$cert_id" ]; then
            echo "failed to scrape CSRF or cert ID from ${printerUrl} (sign-in likely failed)" >&2
            exit 1
          fi

          # 4. Upload the PFX
          $CURL -X POST \
            "https://${printerUrl}/hp/device/CertificatesTabs/Save?jsAnchor=IdentityCertificatesViewSectionId" \
            -F "CSRFToken=$upload_csrf" \
            -F "curSelTab=CertificateManagementController" \
            -F "InstallCertConsolidateID=importCertificate" \
            -F "SignedCertFile=@$pfx;type=application/octet-stream" \
            -F "certPassword=$pfx_pass" \
            -F "certificateFile=;filename=" \
            -F "certificatesRadioList=$cert_id" \
            -F "InstallButton=Install" \
            -F "StepBackAnchor=IdentityCertificatesViewSectionId" \
            -F "jsAnchor=IdentityCertificatesViewSectionId" \
            -o /tmp/cert-upload-response.html \
            -w "${printerUrl}: HTTP %{http_code}\n"

          # Check for error banner in response
          if ${pkgs.gnugrep}/bin/grep -q 'message-error' /tmp/cert-upload-response.html; then
            err=$(${pkgs.gnugrep}/bin/grep -oP '<h2>\K[^<]+' /tmp/cert-upload-response.html | ${pkgs.coreutils}/bin/head -n1)
            echo "${printerUrl}: install failed: $err" >&2
            exit 1
          fi
        '';
      in
      lib.mkIf (certCfg.printerUrls != [ ]) (
        lib.concatMapStringsSep "\n" (url: ''
          ( ${uploadScript url} ) || echo "cert upload failed for ${url}" >&2
        '') certCfg.printerUrls
      );
  };
}
