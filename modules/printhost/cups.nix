{ lib, config, ... }:

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

    systemd.services.cups.preStart = ''
      install -m 600 ${./conf/printers.conf} /var/lib/cups/printers.conf
      install -m 600 ${./conf/classes.conf} /var/lib/cups/classes.conf

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
        # Ensure config changes made in the web interface are temporary
        what = "tmpfs";
        where = "/var/lib/cups";
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
