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
    exec ${pkgs.python3.withPackages (ps: [ ps.ocflib ])}/bin/python3 \
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
              access = [ "change-password" ];
              target = "*@OCF.BERKELEY.EDU";
            }
            # create/admin is used by account creation tooling (ocflib)
            {
              principal = "create/admin";
              access = [
                "add"
                "get"
                "change-password"
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

    environment.systemPackages = [ pkgs.heimdal ];

  };
}
