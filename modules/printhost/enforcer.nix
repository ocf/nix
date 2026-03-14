{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.printhost;

  enforcerPcPkg = pkgs.writeShellApplication {
    name = "enforcer-pc";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk ];
    text = builtins.readFile ./scripts/enforcer-pc.sh;
  };

  enforcerSizePkg = pkgs.writeShellApplication {
    name = "enforcer-size";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk ];
    text = builtins.readFile ./scripts/enforcer-size.sh;
  };

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    ocflib
    redis
    requests
    pycups
    prometheus-client
    pymysql
  ]);

  enforcerBackendPy = pkgs.replaceVars ./scripts/enforcer.py {
    enforcerPc = lib.getExe enforcerPcPkg;
    enforcerSize = lib.getExe enforcerSizePkg;
    socketBackend = "${pkgs.cups}/lib/cups/backend/socket";
    ippBackend = "${pkgs.cups}/lib/cups/backend/ipp";
  };
  enforcerBackend = pkgs.writeShellScript "enforcer" ''
    exec ${pythonEnv}/bin/python3 ${enforcerBackendPy} "$@"
  '';

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

in
{
  config = lib.mkIf cfg.enable {
    ocf.printhost._enforcerBackend = enforcerBackend;

    services.printing.extraFilesConf = ''
      SetEnv ENFORCER_MYSQL_PASSWORD ${cfg.mysqlPasswordFile}
      SetEnv ENFORCER_REDIS_HOST ${cfg.redisHost}
      SetEnv ENFORCER_REDIS_PASSWORD ${cfg.redisPasswordFile}
      SetEnv ENFORCER_WAYOUT_PASSWORD ${cfg.wayoutPasswordFile}
    '';

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
  };
}
