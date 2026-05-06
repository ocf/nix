{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.kerberosServer;
in
{
  options.ocf.kerberosServer = {
    enable = lib.mkEnableOption "OCF Kerberos KDC server (MIT krb5)";
  };

  config = lib.mkIf cfg.enable {
    services.kerberos_server = {
      enable = true;
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
    };

    # TODO: port the password quality check to MIT krb5.
    # Firestorm used Heimdal's external-check interface
    # (modules/ocf_kerberos/files/check-pass-strength, backed by ocflib validators).
    # MIT krb5 requires a pwqual shared-library plugin instead — the script logic
    # can be kept but needs a C wrapper that implements the MIT pwqual API.

    environment.systemPackages = [ pkgs.krb5 ];

    # Ensure the KDC state directory exists before agenix deploys secrets into it
    systemd.tmpfiles.rules = [
      "d /var/lib/krb5kdc 0700 root root -"
    ];

    # The KDC database lives in /var/lib/krb5kdc/ and must be initialized manually:
    #   kdb5_util create -r OCF.BERKELEY.EDU -s
    # For migration from Heimdal, extract principals and re-key them under MIT krb5.
    # The stash file (.k5.OCF.BERKELEY.EDU) is created by kdb5_util and unlocks the
    # database at boot — back it up alongside the database dump.
  };
}
