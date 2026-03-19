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
      browsed.enable = false;
      browsing = true;
      stateless = true;
      extraConf = lib.mkForce (lib.replaceStrings [ "@cups-url@" ] [ "${config.ocf.printhost.printhostUrl}" ]
        (builtins.readFile ./conf/cupsd.conf));
      extraFilesConf = lib.replaceStrings [ "@hostname@" ] [ "${config.networking.hostName}.ocf.berkeley.edu" ]
        (builtins.readFile ./conf/cups-files.conf);
    };
    
    hardware.printers = {
      # ensureDefaultPrinter = "double";
      ensurePrinters = [
        {
          name = "logjam";
          deviceUri = "ipp://169.229.226.92/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          # ppdOptions = {
          #   Duplex = "DuplexNoTumble";
          #   PageSize = "Letter";
          # };
        }
        {
          name = "papercut";
          deviceUri = "ipp://169.229.226.93/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          # ppdOptions = {
          #   Duplex = "DuplexNoTumble";
          #   PageSize = "Letter";
          # };
        }
        {
          name = "pagefault";
          deviceUri = "ipp://169.229.226.91/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          # ppdOptions = {
          #   Duplex = "DuplexNoTumble";
          #   PageSize = "Letter";
          # };
        }
        {
          name = "epson";
          deviceUri = "ipps://169.229.226.96/ipp/print";
          model = "everywhere";
          location = "OCF lab";
          # ppdOptions = {
          #   Duplex = "DuplexNoTumble";
          #   PageSize = "Letter";
          #   InputSlot = "Alternate";
          # };
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
          if lpstat -p epson >/dev/null 2>&1 \
            && lpstat -p logjam >/dev/null 2>&1 \
            && lpstat -p papercut >/dev/null 2>&1 \
            && lpstat -p pagefault >/dev/null 2>&1; then
            break
          fi
          sleep 10
        done
        
        # Set printer settings
        for dest in epson logjam papercut pagefault; do
          lpadmin -p "$dest" -o Duplex=DuplexNoTumble
          lpadmin -p "$dest" -o PageSize=Letter
          # lpadmin -p "$dest" -o job-hold-until-default=indefinite
        done
        lpadmin -p epson -o InputSlot=Alternate

        # add printers to classes
        lpadmin -p epson -c color
        lpadmin -p logjam -c monochrome
        lpadmin -p pagefault -c monochrome
        lpadmin -p papercut -c monochrome

        # for dest in epson-single logjam-single pagefault-single papercut-single color-single single; do
        #   lpadmin -p "$dest" -o Duplex-default=None
        #   lpadmin -p "$dest" -o Duplex=None
        # done
        # for dest in epson-double logjam-double pagefault-double papercut-double color-double double; do
        #   lpadmin -p "$dest" -o Duplex-default=DuplexNoTumble
        #   lpadmin -p "$dest" -o Duplex=DuplexNoTumble
        # done
        
        

        # for dest in \
        #   epson-single epson-double \
        #   logjam-single pagefault-single papercut-single \
        #   logjam-double pagefault-double papercut-double
        # do
        #   lpadmin -p "$dest" -o job-hold-until-default=indefinite
        # done

        for dest in color monochrome; do
          lpadmin -p "$dest" -o printer-is-shared=true
          # lpadmin -p "$dest" -o job-hold-until-default=indefinite
          
          cupsenable "$dest"
          cupsaccept "$dest"
        done
      '';
    };

    networking.firewall = {
      allowedTCPPorts = [ 80 443 631 ];
      allowedUDPPorts = [ 631 ];
    };
  };
}
