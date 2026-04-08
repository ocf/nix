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

  # enforcer-pc: reads %%Pages: from PostScript spool file.
  # Uses explicit Nix store paths for head/tail/awk — these run as subprocesses
  # of the backend, which inherits CUPS's restricted PATH.
  enforcerPc = pkgs.writeShellScript "enforcer-pc" ''
    set -euo pipefail
    ${pkgs.gawk}/bin/awk '/^%%Pages: [0-9]+$/ {print $2; exit}' "$1"
  '';

  # enforcer-size: reads %%DocumentMedia:/%%PageMedia: from PostScript spool file.
  enforcerSize = pkgs.writeShellScript "enforcer-size" ''
    set -euo pipefail
    ${pkgs.gawk}/bin/awk '
        /^%%PageMedia:/    {print $2; exit}
        /^%%DocumentMedia:/ {print $2; exit}
      ' "$1"
  '';

  # enforcer.py with @enforcer_pc@ and @enforcer_size@ paths substituted
  enforcerScript = pkgs.replaceVars ./scripts/enforcer.py {
    enforcer_pc = enforcerPc;
    enforcer_size = enforcerSize;
  };

  # Wrapper that invokes enforcer.py with the right Python environment
  enforcerBin = pkgs.writeShellScript "enforcer" ''
    exec ${pythonEnv}/bin/python3 ${enforcerScript} "$@"
  '';

  # ocfps CUPS filter: PDF → rasterized PostScript via pdftops | pstops
  ocfpsFilter = pkgs.replaceVars ./scripts/ocfps {
    pdftops = "${pkgs.poppler-utils}/bin/pdftops";
    pstops = "${pkgs.cups}/lib/cups/filter/pstops";
    qpdf = "${pkgs.qpdf}/bin/qpdf";
    grep = "${pkgs.gnugrep}/bin/grep";
    awk = "${pkgs.gawk}/bin/awk";
  };

  # Shell wrapper so the filter runs under the Nix-store bash rather than
  # relying on bash being in PATH (CUPS filters run in a restricted env).
  ocfpsBin = pkgs.writeShellScript "ocfps" ''
    exec ${pkgs.bash}/bin/bash ${ocfpsFilter} "$@"
  '';

  # Package exposing ocfps at $out/lib/cups/filter/ocfps for services.printing.drivers
  ocfCupsFilter = pkgs.runCommand "ocf-cups-filter" { } ''
    install -Dm0755 ${ocfpsBin} $out/lib/cups/filter/ocfps
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

  # PPD files package — all printers reference these at setup time
  ppdDir = pkgs.runCommand "printhost-ppds" { } ''
    install -Dm0644 ${./ppd/logjam-single.ppd}    $out/share/ppd/logjam-single.ppd
    install -Dm0644 ${./ppd/logjam-double.ppd}    $out/share/ppd/logjam-double.ppd
    install -Dm0644 ${./ppd/pagefault-single.ppd} $out/share/ppd/pagefault-single.ppd
    install -Dm0644 ${./ppd/pagefault-double.ppd} $out/share/ppd/pagefault-double.ppd
    install -Dm0644 ${./ppd/papercut-single.ppd}  $out/share/ppd/papercut-single.ppd
    install -Dm0644 ${./ppd/papercut-double.ppd}  $out/share/ppd/papercut-double.ppd
    install -Dm0644 ${./ppd/epson-single.ppd}     $out/share/ppd/epson-single.ppd
    install -Dm0644 ${./ppd/epson-double.ppd}     $out/share/ppd/epson-double.ppd
  '';

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
      # Substitute the public hostname into ServerName
      extraConf = lib.mkForce (
        lib.replaceStrings [ "@cups-url@" ] [ cfg.printhostUrl ] (builtins.readFile ./conf/cupsd.conf)
      );
      extraFilesConf = builtins.readFile ./conf/cups-files.conf;
      # Expose our custom filter and backend to cupsd
      drivers = [
        ocfCupsFilter
        ocfCupsBackend
      ];
    };

    systemd.services.cups.preStart = ''
      # /var/lib/cups is a tmpfs (stateless = true), so this runs every boot.
      # CUPS resolves its SSL cert by the machine's actual hostname, not ServerName,
      # so we name the files after the host. The cert includes printhostUrl as a SAN
      # so clients connecting to either hostname get a valid cert.
      mkdir -p /var/lib/cups/ssl
      cp /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/fullchain.pem \
        /var/lib/cups/ssl/${config.networking.hostName}.ocf.berkeley.edu.crt
      cp /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/key.pem \
        /var/lib/cups/ssl/${config.networking.hostName}.ocf.berkeley.edu.key
      cp /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/fullchain.pem \
        "/var/lib/cups/ssl/${config.networking.hostName}.OCF.Berkeley.EDU.crt"
      cp /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/key.pem \
        "/var/lib/cups/ssl/${config.networking.hostName}.OCF.Berkeley.EDU.key"

      # Deny raw job submission (clients must go through filters)
      echo '# deny printing raw jobs' > /etc/cups/raw.convs
      echo '# deny printing raw jobs' > /etc/cups/raw.types
    '';

    # Declaratively configure all printers and classes on every boot.
    # Runs after cups.service since /var/lib/cups is stateless.
    systemd.services.cups-setup-printers = {
      description = "Declaratively configure CUPS printers and classes";
      after = [ "cups.service" ];
      wants = [ "cups.service" ];
      wantedBy = [ "cups.service" ];
      partOf = [ "cups.service" ];
      path = [ config.services.printing.package ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail

        # Wait for cupsd socket to be ready
        for i in $(seq 1 30); do
          if lpstat -H >/dev/null 2>&1; then break; fi
          sleep 2
        done

        # ── HP LaserJet printers (socket/9100 raw TCP) ──────────────────────
        lpadmin -p logjam-single \
          -v ocfbackend:socket://169.229.226.92:9100 \
          -P ${ppdDir}/share/ppd/logjam-single.ppd \
          -D "HP LaserJet M806 single-sided" -L "OCF lab" \
          -E -o printer-is-shared=false

        lpadmin -p logjam-double \
          -v ocfbackend:socket://169.229.226.92:9100 \
          -P ${ppdDir}/share/ppd/logjam-double.ppd \
          -D "HP LaserJet M806 double-sided" -L "OCF lab" \
          -E -o printer-is-shared=false

        lpadmin -p pagefault-single \
          -v ocfbackend:socket://169.229.226.91:9100 \
          -P ${ppdDir}/share/ppd/pagefault-single.ppd \
          -D "HP LaserJet M806 single-sided" -L "OCF lab" \
          -E -o printer-is-shared=false

        lpadmin -p pagefault-double \
          -v ocfbackend:socket://169.229.226.91:9100 \
          -P ${ppdDir}/share/ppd/pagefault-double.ppd \
          -D "HP LaserJet M806 double-sided" -L "OCF lab" \
          -E -o printer-is-shared=false

        lpadmin -p papercut-single \
          -v ocfbackend:socket://169.229.226.93:9100 \
          -P ${ppdDir}/share/ppd/papercut-single.ppd \
          -D "HP LaserJet M806 single-sided" -L "OCF lab" \
          -E -o printer-is-shared=false

        lpadmin -p papercut-double \
          -v ocfbackend:socket://169.229.226.93:9100 \
          -P ${ppdDir}/share/ppd/papercut-double.ppd \
          -D "HP LaserJet M806 double-sided" -L "OCF lab" \
          -E -o printer-is-shared=false

        # ── Epson ET-5880 (IPP/S) ────────────────────────────────────────────
        lpadmin -p epson-single \
          -v ocfbackend:ipps://169.229.226.96/ipp/print \
          -P ${ppdDir}/share/ppd/epson-single.ppd \
          -D "Epson ET-5880 single-sided color" -L "OCF lab" \
          -E -o printer-is-shared=false

        lpadmin -p epson-double \
          -v ocfbackend:ipps://169.229.226.96/ipp/print \
          -P ${ppdDir}/share/ppd/epson-double.ppd \
          -D "Epson ET-5880 double-sided color" -L "OCF lab" \
          -E -o printer-is-shared=false

        # ── Classes ──────────────────────────────────────────────────────────
        for p in logjam-double pagefault-double papercut-double; do
          lpadmin -p "$p" -c double
        done
        lpadmin -p double -D "Double-sided printing" -L "OCF lab"

        for p in logjam-single pagefault-single papercut-single; do
          lpadmin -p "$p" -c single
        done
        lpadmin -p single -D "Single-sided printing" -L "OCF lab"

        lpadmin -p epson-single -c color-single
        lpadmin -p color-single -D "Single-sided color printing" -L "OCF lab"

        lpadmin -p epson-double -c color-double
        lpadmin -p color-double -D "Double-sided color printing" -L "OCF lab"

        # Enable and accept jobs for all classes (shared with clients)
        for cls in single double color-single color-double; do
          cupsenable "$cls"
          cupsaccept "$cls"
          lpadmin -p "$cls" -o printer-is-shared=true
        done
      '';
    };

    # prevent conflict with cups built in mDNS
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
