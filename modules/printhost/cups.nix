{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.ocf.printhost;
in
{
  # use nixos-unstable printers module to include nixpkgs pr #558981 and #524127
  # FIXME remove after nixos-26.11 upgrade
  disabledModules = [
    "hardware/printers.nix"
  ];
  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/hardware/printers.nix"
  ];

  config = lib.mkIf cfg.enable {

    services.printing = {
      enable = true;
      startWhenNeeded = false;
      browsed.enable = false;
      browsing = false;
      stateless = true;
      webInterface = true;
      defaultShared = true;
      listenAddresses = [
        "*:631"
        "*:443"
      ];
      openFirewall = true;
      # using lib.mkForce to overwrite the default extraConf
      extraConf = lib.mkForce ''
        ServerName ${config.networking.fqdn}
        ServerAlias ${config.networking.hostName}.ocf.io ${cfg.subdomain}.ocf.berkeley.edu ${cfg.subdomain}.ocf.io # matches the list of CNAMEs

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
        ServerKeychain /etc/cups-certs
      '';
    };

    hardware.printers =
      let
        bwPrinters = [
          "logjam"
          "papercut"
          "pagefault"
        ];
      in
      {
        ensurePrinters =
          (map (printer: {
            name = printer;
            model = "everywhere";
            description = "HP LaserJet M806";
            location = "OCF lab";
            deviceUri = "ipps://${printer}.ocf.berkeley.edu?waitjob=false&waitprinter=false";
            ppdOptions = {
              printer-is-shared = "false"; # don't share the individual printers in the class
              Duplex = "DuplexNoTumble";
            };
          }) bwPrinters)
          ++ [
            {
              name = "OCF-Color";
              model = "everywhere";
              description = "HP Color LaserJet M856";
              location = "OCF lab";
              deviceUri = "ipps://fishpaper.ocf.berkeley.edu?waitjob=false&waitprinter=false";
            }
          ];

        ensureClasses = {
          OCF-BW = {
            location = "OCF lab";
            printers = bwPrinters;
          };
        };
      };

    systemd.services.cups.postStart = lib.mkAfter ''
      lpadmin -p OCF-BW -o job-hold-until-default=indefinite
      lpadmin -p OCF-Color -o job-hold-until-default=indefinite
    '';

    services.avahi.enable = lib.mkForce false;
  };
}
