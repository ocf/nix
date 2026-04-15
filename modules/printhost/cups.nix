{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.printhost;

  # Python environment for the enforcer quota script
  pythonEnv = pkgs.python312.withPackages (
    ps: with ps; [
      ocflib
      pycups
      pymysql
      requests
      redis
    ]
  );

  enforcerScript = pkgs.replaceVars ./scripts/enforcer.py {
    qpdf = "${pkgs.qpdf}/bin/qpdf";
  };

  # Wrapper that invokes enforcer.py with the right Python environment
  enforcerBin = pkgs.writeShellScript "enforcer" ''
    exec ${pythonEnv}/bin/python3 ${enforcerScript} "$@"
  '';

  # ocf-cups-backend with enforcer path and password file paths substituted.
  # mysqlPasswordFile/wayoutPasswordFile/redisPasswordFile are paths to agenix secrets.
  ocfBackendScript = pkgs.replaceVars ./scripts/ocf-cups-backend {
    enforcer = enforcerBin;
    mysqlPasswordFile = cfg.mysqlPasswordFile;
    wayoutPasswordFile = cfg.wayoutPasswordFile;
    redisPasswordFile = cfg.redisPasswordFile;
  };

  # Shell wrapper so the backend runs under the Nix-store python3 rather than
  # relying on python3 being in PATH (CUPS backends run in a restricted env).
  ocfBackendBin = pkgs.writeShellScript "ocfbackend" ''
    exec ${pythonEnv}/bin/python3 ${ocfBackendScript} "$@"
  '';

  # Package exposing the backend at $out/lib/cups/backend/ocfbackend (mode 0700
  # so CUPS runs it as root, which is required for raw socket access to printers)
  ocfCupsBackend = pkgs.runCommand "ocf-cups-backend" { } ''
    install -Dm0700 ${ocfBackendBin} $out/lib/cups/backend/ocfbackend
  '';

  # Use official PPDs unmodified; defaults are set via lpadmin -o below.
  hpPpd = "${pkgs.hplip}/share/cups/model/HP/hp-laserjet_m806-ps.ppd.gz";
  epsonPpd = "${pkgs.epson-escpr2}/share/cups/model/epson-inkjet-printer-escpr2/Epson-ET-5880_Series-epson-escpr2-en.ppd";

in
{
  config = lib.mkIf cfg.enable {

    services.printing = {
      enable = true;
      startWhenNeeded = false;
      listenAddresses = [
        "*:80"
        "*:631"
      ];
      browsed.enable = false;
      browsing = false;
      stateless = true;
      # Substitute the public hostname into ServerName, and switch to
      # Negotiate (GSSAPI/Kerberos) auth when a keytab is configured.
      extraConf = lib.mkForce (
        lib.replaceStrings
          [
            "@cups-url@"
          ]
          [
            "${config.networking.hostName}.ocf.berkeley.edu"
          ]
          (builtins.readFile ./conf/cupsd.conf)
      );
      extraFilesConf = builtins.readFile ./conf/cups-files.conf;
      # hplip provides hpps (HP PPD filter); epson-escpr2 provides epson-escpr-wrapper2.
      drivers = [
        ocfCupsBackend
        pkgs.hplip
        pkgs.epson-escpr2
      ];
    };

    # /var/lib/cups is a tmpfs (stateless = true), so this runs every boot.
    # CUPS resolves its SSL cert by the machine's actual hostname, not ServerName,
    # so we name the files after the host. The cert includes printhostUrl as a SAN
    # so clients connecting to either hostname get a valid cert.
    systemd.services.cups-ssl-certs = {
      description = "Copy ACME certificates into CUPS SSL directory";
      after = [
        "cups.service"
        "acme-${config.networking.hostName}.ocf.berkeley.edu.service"
      ];
      wants = [ "acme-${config.networking.hostName}.ocf.berkeley.edu.service" ];
      wantedBy = [ "cups.service" ];
      partOf = [ "cups.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        ln -sf /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/fullchain.pem \
          /var/lib/cups/ssl/${config.networking.hostName}.ocf.berkeley.edu.crt
        ln -sf /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/key.pem \
          /var/lib/cups/ssl/${config.networking.hostName}.ocf.berkeley.edu.key
        ln -sf /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/fullchain.pem \
          "/var/lib/cups/ssl/${config.networking.hostName}.OCF.Berkeley.EDU.crt"
        ln -sf /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/key.pem \
          "/var/lib/cups/ssl/${config.networking.hostName}.OCF.Berkeley.EDU.key"
      '';
    };

    # Declaratively configure all printers and classes on every boot.
    # Runs after cups.service since /var/lib/cups is stateless.
    systemd.services.cups-setup-printers = {
      description = "Declaratively configure CUPS printers and classes";
      after = [ "cups.service" ];
      wants = [ "cups.service" ];
      wantedBy = [ "multi-user.target" ];
      partOf = [ "cups.service" ];
      path = [ config.services.printing.package ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail

        lpadmin -p logjam \
          -v ocfbackend:socket://169.229.226.92:9100 \
          -m raw \
          -D "HP LaserJet M806" -L "OCF lab" \
          -E -o printer-is-shared=false -o Duplex=DuplexNoTumble

        lpadmin -p papercut \
          -v ocfbackend:socket://169.229.226.93:9100 \
          -m raw \
          -D "HP LaserJet M806" -L "OCF lab" \
          -E -o printer-is-shared=false -o Duplex=DuplexNoTumble
          
        lpadmin -p pagefault \
          -v ocfbackend:socket://169.229.226.91:9100 \
          -m raw \
          -D "HP LaserJet M806" -L "OCF lab" \
          -E -o printer-is-shared=false -o Duplex=DuplexNoTumble

        lpadmin -p logjam    -c OCF-BW-Group
        lpadmin -p papercut  -c OCF-BW-Group
        lpadmin -p pagefault -c OCF-BW-Group
        lpadmin -p OCF-BW-Group -E -o printer-is-shared=false \
          -D "HP LaserJet M806" -L "OCF lab"

        # ── Public Printers -------------─────────────────────────────────────
        lpadmin -p OCF-BW \
          -v "ipp://localhost/classes/OCF-BW-Group?waitjob=false&waitprinter=false" \
          -P ${hpPpd} \
          -D "OCF Black & White" -L "OCF lab" \
          -E -o printer-is-shared=true -o Duplex=DuplexNoTumble
        lpadmin -p OCF-Color \
          -v ocfbackend:socket://169.229.226.96:9100 \
          -P ${epsonPpd} \
          -D "OCF Color" -L "OCF lab" \
          -E -o printer-is-shared=true -o Duplex=None -o PageSize=Letter

        # remove hpps from ppd
        sed -i 's/^\*cupsFilter:.*hpps.*/%&/' /etc/cups/ppd/OCF-BW.ppd
      '';
    };

    services.avahi.enable = lib.mkForce false;

    networking.firewall = {
      allowedTCPPorts = [
        80
        443
        631
      ];
      allowedUDPPorts = [ 631 ];
    };
  };
}
