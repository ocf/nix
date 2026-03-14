{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.printhost;

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    ocflib
    pycups
    pymysql
    requests
  ]);

  privacyCleanupScript = pkgs.writeText "enforcer-privacy-cleanup.py" ''
    import os
    import pymysql

    mysql_passwd = open(os.environ['ENFORCER_MYSQL_PASSWORD']).read().strip()
    conn = pymysql.connect(
        host='mysql.ocf.berkeley.edu',
        user='ocfprinting',
        password=mysql_passwd,
        db='ocfprinting',
    )
    with conn:
        with conn.cursor() as c:
            c.execute(
                'UPDATE jobs SET doc_name = NULL '
                'WHERE time < DATE_SUB(NOW(), INTERVAL 14 DAY)'
            )
        conn.commit()
  '';

  privacyCleanupBin = pkgs.writeShellScript "enforcer-privacy-cleanup" ''
    exec ${pythonEnv}/bin/python3 ${privacyCleanupScript}
  '';

  submitGateScript = pkgs.writeText "enforcer-submit-gate.py"
    (builtins.readFile ./scripts/submit-gate.py);

  submitGateBin = pkgs.writeShellScript "enforcer-submit-gate" ''
    exec ${pythonEnv}/bin/python3 ${submitGateScript}
  '';

  ippAccountingScript = pkgs.writeText "ipp-accounting.py"
    (builtins.readFile ./scripts/ipp-accounting.py);

  ippAccountingBin = pkgs.writeShellScript "ipp-accounting" ''
    exec ${pythonEnv}/bin/python3 ${ippAccountingScript}
  '';

in
{
  config = lib.mkIf cfg.enable {
    # ocflib hardcodes /usr/sbin/sendmail; on NixOS postfix provides it at
    # /run/wrappers/bin/sendmail via security.wrappers.
    systemd.tmpfiles.rules = [
      "L /usr/sbin/sendmail - - - - /run/wrappers/bin/sendmail"
    ];

    # Hourly job to NULL out doc_name for jobs older than 14 days (privacy).
    systemd.services.enforcer-privacy-cleanup = {
      description = "Remove old print job document titles for privacy";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${privacyCleanupBin}";
      };
      environment = {
        ENFORCER_MYSQL_PASSWORD = cfg.mysqlPasswordFile;
      };
    };

    systemd.timers.enforcer-privacy-cleanup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1h";
        OnUnitActiveSec = "1h";
      };
    };

    systemd.services.enforcer-submit-gate = {
      description = "Reject over-quota jobs shortly after submission";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${submitGateBin}";
      };
      environment = {
        ENFORCER_MYSQL_PASSWORD = cfg.mysqlPasswordFile;
        ENFORCER_WAYOUT_PASSWORD = cfg.wayoutPasswordFile;
      };
    };

    systemd.timers.enforcer-submit-gate = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2s";
        OnUnitActiveSec = "1s";
      };
    };

    systemd.services.ipp-accounting = {
      description = "Account completed IPP jobs into quota DB";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${ippAccountingBin}";
      };
      environment = {
        ENFORCER_MYSQL_PASSWORD = cfg.mysqlPasswordFile;
        ENFORCER_WAYOUT_PASSWORD = cfg.wayoutPasswordFile;
      };
    };

    systemd.timers.ipp-accounting = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "5s";
      };
    };
  };
}
