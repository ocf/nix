{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.kerberosKdc;

  # check-pass-strength wrapped with a Python environment that has ocflib.
  checkPassStrength = pkgs.writeShellScript "check-pass-strength" ''
    exec ${pkgs.python312.withPackages (ps: [ ps.ocflib ])}/bin/python3 \
      ${./check-pass-strength.py} "$@"
  '';
in
{
  options.ocf.kerberosKdc = {
    enable = lib.mkEnableOption "OCF Kerberos KDC server (Heimdal)";
  };

  # The KDC database lives in /var/lib/heimdal/ and must be initialized manually:
  #   kadmin -l init OCF.BERKELEY.EDU
  # For migration between hosts, dump with: kadmin -l dump <file>
  # and restore with: kadmin -l load <file>

  config = lib.mkIf cfg.enable {
    services.kerberos_server = {
      enable = true;
      settings = {
        kdc.extra-addresses = "127.0.0.2";
        kdc.enable-fast = false;

        realms."OCF.BERKELEY.EDU" = {
          acl = [
            # Staff /admin principals have full KDC access
            {
              principal = "*/admin";
              access = [ "all" ];
            }
            # Staff /root principals can change any principal's password
            {
              principal = "*/root";
              access = [ "cpw" ];
              target = "*@OCF.BERKELEY.EDU";
            }
            # create/admin is used by account creation tooling (ocflib)
            {
              principal = "create/admin";
              access = [
                "add"
                "get"
                "cpw"
              ];
              target = "*@OCF.BERKELEY.EDU";
            }
          ];
        };

        # a wrapper for ocflib's `validate_password`. more complex than doing
        # it natively, but good to standardize password requirements across
        # ocf/utils and ocf/ocfweb. heimdal's external password checking like
        # this might not be easily possible in MIT...? consider if migrating
        # off of heimdal kerb.

        password_quality = {
          policies = "external-check";
          external_program = "${checkPassStrength}";
        };
      };
    };

    # KDC must start after slapd so SASL/GSSAPI is available for KDC → LDAP lookups
    systemd.services.kdc.after = [ "openldap.service" ];

    environment.systemPackages = [ pkgs.heimdal ];

    networking.firewall = {
      allowedTCPPorts = [
        88 # kerberos
        749 # kadmin
      ];
      allowedUDPPorts = [
        88 # kerberos
        464 # kpasswd
      ];
    };

    systemd.tmpfiles.rules = [
      "d /var/backups/kerberos 0700 root root -"
    ];

    # unlike LDAP, not uploaded to github (for now?)
    systemd.services.kerberos-git-backup = {
      description = "Kerberos KDC git backup";
      after = [ "kdc.service" ];
      requires = [ "kdc.service" ];
      path = [
        pkgs.heimdal
        pkgs.git
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        UMask = "0077";
      };
      script = ''
        dir=/var/backups/kerberos
        [ -d "$dir/.git" ] || git -C "$dir" init -q
        kadmin -l dump --decrypt "$dir/kerberos.dump"
        git -C "$dir" add kerberos.dump
        git -C "$dir" commit -q -m 'kerberos-git-backup' --allow-empty kerberos.dump
        git -C "$dir" gc --auto --quiet
      '';
    };

    systemd.timers.kerberos-git-backup = {
      description = "Run Kerberos KDC git backup daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # Run before rsnapshot so the backup server gets a fresh daily snapshot
        OnCalendar = "*-*-* 01:00:00";
        Persistent = true;
      };
    };

  };
}
