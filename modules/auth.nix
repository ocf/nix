{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.auth;
  keytabSecretPath = ../secrets/master-keyed/keytabs + "/${config.networking.hostName}.age";
  hasKeytab = builtins.pathExists keytabSecretPath;
in
{
  options.ocf.auth = {
    enable = lib.mkEnableOption "Enable OCF authentication";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.root-password-hash.rekeyFile = ../secrets/master-keyed/root-password-hash.age;

    # Per-host keytab for GSSAPI SSH authentication
    # Only configured if the host has a keytab in secrets/master-keyed/keytabs/<hostname>.age
    age.secrets.krb5-keytab = lib.mkIf hasKeytab {
      rekeyFile = keytabSecretPath;
      path = "/etc/krb5.keytab";
      owner = "root";
      group = "root";
      mode = "0600";
    };

    users = {
      mutableUsers = false;
      users.root.hashedPasswordFile = config.age.secrets.root-password-hash.path;

      ldap = {
        enable = true;
        server = "ldaps://ldap.ocf.berkeley.edu";
        base = "dc=OCF,dc=Berkeley,dc=EDU";
        daemon.enable = true;
        extraConfig = ''
          tls_reqcert hard
          tls_cacert /etc/ssl/certs/ca-certificates.crt

          base dc=ocf,dc=berkeley,dc=edu
          nss_base_passwd ou=people,dc=ocf,dc=berkeley,dc=edu
          nss_base_group  ou=group,dc=ocf,dc=berkeley,dc=edu
        '';
      };
    };

    security.sudo = {
      extraConfig = ''
        Defaults passprompt="[sudo] password for %u/root: "
      '';

      extraRules = [
        { groups = [ "ocfroot" ]; commands = [ "ALL" ]; }
        { users = [ "ocfbackups" ]; commands = [{ command = lib.getExe pkgs.rsync; options = [ "NOPASSWD" ]; }]; }
      ];
    };

    security.pam.services.sudo.text =
      let
        pam_krb5_so = "${pkgs.pam_krb5}/lib/security/pam_krb5.so";
      in
      ''
        # use /root principal to sudo
        auth required ${pam_krb5_so} minimum_uid=1000 alt_auth_map=%s/root only_alt_auth no_ccache
        account required pam_unix.so

        # common-session-noninteractive
        session [default=1] pam_permit.so
        session requisite pam_deny.so
        session required pam_permit.so
        session optional ${pam_krb5_so} minimum_uid=1000
        session required pam_unix.so

        # reset user limits
        session required pam_limits.so
      '';

    security.krb5 = {
      enable = true;
      package = pkgs.heimdal;

      settings = {
        realms."OCF.BERKELEY.EDU" = {
          admin_server = "kerberos.ocf.berkeley.edu";
          kdc = [ "kerberos.ocf.berkeley.edu" ];
        };
        domain_realm = {
          "ocf.berkeley.edu" = "OCF.BERKELEY.EDU";
          ".ocf.berkeley.edu" = "OCF.BERKELEY.EDU";
        };
        libdefaults = {
          default_realm = "OCF.BERKELEY.EDU";
        };
      };
    };

    services.openssh.settings = {
      GSSAPIAuthentication = "yes";
      GSSAPICleanupCredentials = "yes";
      GSSAPIStrictAcceptorCheck = "no";
      # Only enable key exchange if host has a keytab
      GSSAPIKeyExchange = lib.mkIf hasKeytab "yes";
    };
  };
}
