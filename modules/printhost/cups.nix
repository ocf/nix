{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.printhost;

  ocfpsFilter = pkgs.replaceVars ./scripts/ocfps.sh {
    pdftops = "${pkgs.poppler-utils}/bin/pdftops";
    pstops = "${pkgs.cups}/lib/cups/filter/pstops";
  };

  ppdSingle = ./ppd/m806-single.ppd;
  ppdDouble = ./ppd/m806-double.ppd;
  ppdEpson = ./ppd/epson.ppd;

  cupsDriverPackage = pkgs.runCommand "ocf-cups-drivers" { } ''
    mkdir -p $out/lib/cups/backend $out/lib/cups/filter $out/share/cups/model
    install -m 700 ${cfg._enforcerBackend}  $out/lib/cups/backend/enforcer
    install -m 755 ${ocfpsFilter}           $out/lib/cups/filter/ocfps
    install -m 644 ${ppdSingle}             $out/share/cups/model/ocf-m806-single.ppd
    install -m 644 ${ppdDouble}             $out/share/cups/model/ocf-m806-double.ppd
    install -m 644 ${ppdEpson}              $out/share/cups/model/ocf-epson.ppd
  '';

in
{
  config = lib.mkIf cfg.enable {

    services.printing = {
      enable = true;
      drivers = [ cupsDriverPackage ];
      listenAddresses = [ "*:80" "*:631" ];
      extraConf = lib.mkForce (builtins.readFile ./conf/cupsd.conf);
      extraFilesConf = lib.replaceStrings [ "@hostname@" ] [ "${config.networking.hostName}.ocf.berkeley.edu" ]
        (builtins.readFile ./conf/cups-files.conf);
    };

    # base.nix sets these settings for all machines (for use on dekstops),
    # but the printing module enabled on tule sets /etc/cups as a symlink to
    # /var/lib/cups, causing a conflict
    environment.etc."cups/lpoptions".enable = lib.mkForce false;
    environment.etc."cups/client.conf".enable = lib.mkForce false;

    systemd.services.cups.preStart = ''
      install -m 600 ${./conf/printers.conf} /var/lib/cups/printers.conf
      install -m 600 ${./conf/classes.conf} /var/lib/cups/classes.conf
      mkdir -p /var/lib/cups/ppd
      for name in logjam-double logjam-single pagefault-double pagefault-single papercut-double papercut-single; do
        case $name in
          *-double) install -m 644 ${ppdDouble} /var/lib/cups/ppd/$name.ppd ;;
          *-single) install -m 644 ${ppdSingle} /var/lib/cups/ppd/$name.ppd ;;
        esac
      done
      install -m 644 ${ppdEpson}     /var/lib/cups/ppd/epson.ppd
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
