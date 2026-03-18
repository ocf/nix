{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.printhost;

in
{
  config = lib.mkIf cfg.enable {

    services.printing = {
      enable = true;
      startWhenNeeded = false;
      listenAddresses = [ "*:80" "*:631" ];
      extraConf = lib.mkForce (lib.replaceStrings [ "@cups-url@" ] [ "${config.ocf.printhost.printhostUrl}" ]
        (builtins.readFile ./conf/cupsd.conf));
      extraFilesConf = lib.replaceStrings [ "@hostname@" ] [ "${config.networking.hostName}.ocf.berkeley.edu" ]
        (builtins.readFile ./conf/cups-files.conf);
    };
    
    hardware.printers = {
      ensureDefaultPrinter = "double";
      ensurePrinters = [
        {
          name = "logjam-double";
          deviceUri = "ipp://169.229.226.92/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "DuplexNoTumble";
          };
        }
        {
          name = "logjam-single";
          deviceUri = "ipp://169.229.226.92/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "None";
          };
        }
        {
          name = "pagefault-double";
          deviceUri = "ipp://169.229.226.91/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "DuplexNoTumble";
          };
        }
        {
          name = "pagefault-single";
          deviceUri = "ipp://169.229.226.91/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "None";
          };
        }
        {
          name = "papercut-double";
          deviceUri = "ipp://169.229.226.93/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "DuplexNoTumble";
          };
        }
        {
          name = "papercut-single";
          deviceUri = "ipp://169.229.226.93/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "None";
          };
        }
        {
          name = "epson-double";
          deviceUri = "ipp://169.229.226.96/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "DuplexNoTumble";
            PageSize = "Letter";
            InputSlot = "Alternate";
          };
        }
        {
          name = "epson-single";
          deviceUri = "ipp://169.229.226.96/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          ppdOptions = {
            Duplex = "None";
            PageSize = "Letter";
            InputSlot = "Alternate";
          };
        }
      ];
    };

    systemd.services.cups.preStart = ''
      # Pre-populate CUPS ssl dir with the LE cert so CUPS doesn't regenerate
      # a self-signed cert. /var/lib/cups is a tmpfs so this runs every start.
      mkdir -p /var/lib/cups/ssl
      cp /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/fullchain.pem \
        /var/lib/cups/ssl/${config.networking.hostName}.ocf.berkeley.edu.crt
      cp /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/key.pem \
        /var/lib/cups/ssl/${config.networking.hostName}.ocf.berkeley.edu.key
      cp /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/fullchain.pem \
        /var/lib/cups/ssl/${config.networking.hostName}.OCF.Berkeley.EDU.crt
      cp /var/lib/acme/${config.networking.hostName}.ocf.berkeley.edu/key.pem \
        /var/lib/cups/ssl/${config.networking.hostName}.OCF.Berkeley.EDU.key

      echo 'Default double'           > /etc/cups/lpoptions
      echo '# deny printing raw jobs' > /etc/cups/raw.convs
      echo '# deny printing raw jobs' > /etc/cups/raw.types
    '';

    systemd.services.cups-ensure-classes = {
      description = "Declaratively ensure CUPS classes";
      after = [ "cups.service" "ensure-printers.service" ];
      wants = [ "cups.service" "ensure-printers.service" ];
      wantedBy = [ "cups.service" ];
      partOf = [ "cups.service" ];
      path = [ config.services.printing.package pkgs.coreutils ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail

        # Wait briefly for declarative printers to be present before managing classes.
        for _ in $(seq 1 30); do
          if lpstat -p epson-single >/dev/null 2>&1 \
            && lpstat -p epson-double >/dev/null 2>&1 \
            && lpstat -p logjam-single >/dev/null 2>&1 \
            && lpstat -p pagefault-single >/dev/null 2>&1 \
            && lpstat -p papercut-single >/dev/null 2>&1 \
            && lpstat -p logjam-double >/dev/null 2>&1 \
            && lpstat -p pagefault-double >/dev/null 2>&1 \
            && lpstat -p papercut-double >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        lpadmin -x color-single >/dev/null 2>&1 || true
        lpadmin -x color-double >/dev/null 2>&1 || true
        lpadmin -x single >/dev/null 2>&1 || true
        lpadmin -x double >/dev/null 2>&1 || true

        lpadmin -p epson-single -c color-single
        lpadmin -p epson-double -c color-double
        lpadmin -p logjam-single -c single
        lpadmin -p pagefault-single -c single
        lpadmin -p papercut-single -c single
        lpadmin -p logjam-double -c double
        lpadmin -p pagefault-double -c double
        lpadmin -p papercut-double -c double

        for dest in epson-single logjam-single pagefault-single papercut-single color-single single; do
          lpadmin -p "$dest" -o Duplex-default=None
          lpadmin -p "$dest" -o Duplex=None
        done
        for dest in epson-double logjam-double pagefault-double papercut-double color-double double; do
          lpadmin -p "$dest" -o Duplex-default=DuplexNoTumble
          lpadmin -p "$dest" -o Duplex=DuplexNoTumble
        done

        for dest in color-single color-double single double; do
          lpadmin -p "$dest" -o printer-is-shared=true
          lpadmin -p "$dest" -o job-hold-until-default=indefinite
        done

        for dest in \
          epson-single epson-double \
          logjam-single pagefault-single papercut-single \
          logjam-double pagefault-double papercut-double
        do
          lpadmin -p "$dest" -o job-hold-until-default=indefinite
        done

        for dest in \
          epson-single epson-double \
          logjam-single pagefault-single papercut-single \
          logjam-double pagefault-double papercut-double \
          color-single color-double single double
        do
          cupsenable "$dest" >/dev/null 2>&1 || true
          cupsaccept "$dest" >/dev/null 2>&1 || true
        done
      '';
    };


    systemd.mounts = [
      # Ensure print jobs aren't saved persistently for privacy reasons
      {
        what = "tmpfs";
        where = "/var/spool/cups";
        type = "tmpfs";
        options = "mode=0710,gid=lp,noatime,nodev,noexec,nosuid";
        before = [ "cups.service" ];
        wantedBy = [ "cups.service" "multi-user.target" ];
      }
      {
        what = "tmpfs";
        where = "/var/lib/cups";
        type = "tmpfs";
        options = "mode=0710,gid=lp,noatime,nodev,noexec,nosuid";
        before = [ "cups.service" ];
        wantedBy = [ "cups.service" "multi-user.target" ];
      }
      {
        what = "tmpfs";
        where = "/var/cache/cups";
        type = "tmpfs";
        options = "mode=0710,gid=lp,noatime,nodev,noexec,nosuid";
        before = [ "cups.service" ];
        wantedBy = [ "cups.service" "multi-user.target" ];
      }
    ];

    networking.firewall = {
      allowedTCPPorts = [ 80 443 631 ];
      allowedUDPPorts = [ 631 ];
    };
  };
}
