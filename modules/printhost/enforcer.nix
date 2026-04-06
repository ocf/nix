{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ocf.printhost;

  pythonEnv = pkgs.python312.withPackages (
    ps: with ps; [
      ocflib
      pymysql
    ]
  );

  privacyCleanupScript = pkgs.writeText "enforcer-privacy-cleanup.py" ''
    import logging
    import os
    import sys
    import pymysql

    logging.basicConfig(
        level=logging.INFO,
        format="%(message)s",
        stream=sys.stderr,
    )

    logging.info("Starting privacy-cleanup run")
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
            logging.info(f"Cleaned up {c.rowcount} job document titles")
        conn.commit()
    logging.info("Finishing privacy-cleanup run")
  '';

  privacyCleanupBin = pkgs.writeShellScript "enforcer-privacy-cleanup" ''
    exec ${pythonEnv}/bin/python3 ${privacyCleanupScript}
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
        PYTHONUNBUFFERED = "1";
      };
    };

    systemd.timers.enforcer-privacy-cleanup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1h";
        OnUnitActiveSec = "1h";
      };
    };
  };
}
