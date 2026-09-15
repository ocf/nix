{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.printhost;

  # Python environment for the enforcer quota script
  pythonEnv = config.ocf.python.package.withPackages (
    ps: with ps; [
      ocflib
      pycups
      pymysql
      requests
    ]
  );

  enforcerScript = ./scripts/enforcer.py;

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
in
{
  config = lib.mkIf cfg.enable {

    services.printing = {
      enable = true;
      startWhenNeeded = false;
      browsed.enable = false;
      browsing = false;
      stateless = true;
      listenAddresses = [ "*:443" ];
      openFirewall = true;
      extraConf = lib.mkForce ''
        ServerName ${config.networking.fqdn}
        ServerAlias ${config.networking.hostName}.ocf.io printhost.ocf.berkeley.edu printhost.ocf.io # matches the list of CNAMEs

        PreserveJobFiles No

        HostNameLookups On # required for print notifications

        ErrorPolicy retry-job


        <Location />
          Order allow,deny
          Allow from 169.229.226.0/24
          Allow from [2607:f140:8801::]/64
          Allow from localhost
        </Location>

        <Location /jobs>
          Require user @SYSTEM
          Order allow,deny
          Allow from 169.229.226.0/24
          Allow from [2607:f140:8801::]/64
          Allow from localhost
        </Location>

        <Location /admin>
          Require user @SYSTEM
          Order allow,deny
          Allow from 169.229.226.0/24
          Allow from [2607:f140:8801::]/64
          Allow from localhost
        </Location>

        <Location /admin/conf>
          Require user @SYSTEM
          Order allow,deny
          Allow from 169.229.226.0/24
          Allow from [2607:f140:8801::]/64
          Allow from localhost
        </Location>

        <Policy default>
          JobPrivateAccess all
          JobPrivateValues none

          # users can manage their own jobs and @SYSTEM group can manage all jobs
          <Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job CUPS-Move-Job CUPS-Get-Document Cancel-Job CUPS-Authenticate-Job>
            Require user @OWNER @SYSTEM
            Order deny,allow
          </Limit>

          # restrict management to @SYSTEM
          <Limit CUPS-Add-Modify-Printer CUPS-Delete-Printer CUPS-Add-Modify-Class CUPS-Delete-Class CUPS-Set-Default Pause-Printer Resume-Printer Enable-Printer Disable-Printer Pause-Printer-After-Current-Job Hold-New-Jobs Release-Held-New-Jobs Deactivate-Printer Activate-Printer Restart-Printer Shutdown-Printer Startup-Printer Promote-Job Schedule-Job-After CUPS-Accept-Jobs CUPS-Reject-Jobs>
            Require user @SYSTEM
            Order deny,allow
          </Limit>

          <Limit All>
            Order deny,allow
          </Limit>
        </Policy>
      '';
      extraFilesConf = ''
        SystemGroup ocfstaff opstaff
        ServerKeychain /var/lib/acme
      '';
      drivers = [
        ocfCupsBackend
        pkgs.ocf-hplip
      ];
    };

    # Declaratively configure all printers and classes on cups service start.
    # Runs after cups.service since /var/lib/cups is stateless.
    systemd.services.cups-setup-printers = {
      description = "Declaratively configure CUPS printers and classes";
      after = [ "cups.service" ];
      wantedBy = [ "cups.service" ];
      partOf = [ "cups.service" ];
      path = [ config.services.printing.package ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail

        lpadmin -p logjam \
          -v ocfbackend:socket://logjam:9100 \
          -m raw \
          -D "HP LaserJet M806" -L "OCF lab" \
          -E -o printer-is-shared=false -o Duplex=DuplexNoTumble

        lpadmin -p papercut \
          -v ocfbackend:socket://papercut:9100 \
          -m raw \
          -D "HP LaserJet M806" -L "OCF lab" \
          -E -o printer-is-shared=false -o Duplex=DuplexNoTumble

        lpadmin -p pagefault \
          -v ocfbackend:socket://pagefault:9100 \
          -m raw \
          -D "HP LaserJet M806" -L "OCF lab" \
          -E -o printer-is-shared=false -o Duplex=DuplexNoTumble

        lpadmin -p logjam    -c OCF-BW-Group
        lpadmin -p papercut  -c OCF-BW-Group
        lpadmin -p pagefault -c OCF-BW-Group
        lpadmin -p OCF-BW-Group -E -o printer-is-shared=true \
          -D "HP LaserJet M806" -L "OCF lab"

        lpadmin -p OCF-Color \
          -v ocfbackend:socket://fishpaper:9100 \
          -m raw \
          -D "HP Color LaserJet M856" -L "OCF lab" \
          -E -o printer-is-shared=true
      '';
    };

    services.avahi.enable = lib.mkForce false;
  };
}
