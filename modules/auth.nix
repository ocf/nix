{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.auth;
  keytabSecretPath = ../secrets/master-keyed/keytabs + "/${config.networking.hostName}.age";
  keytabPath = "/etc/krb5.keytab";
  hasKeytab = builtins.pathExists keytabSecretPath;
  domain = config.networking.domain;
  realm = lib.toUpper domain;
  kdc = "kerberos.${domain}";
  ldapURI = "ldaps://ldap.${domain}";
  ldapBase = "dc=ocf,dc=berkeley,dc=edu"; # TODO: parse this from config.networking.domain?
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
      path = keytabPath;
      owner = "root";
      group = "root";
      mode = "0600";
    };

    # dont store tickets as files, use kcm instead
    # override systemd service because upstream nixos module is broken
    services.sssd.kcm = true; # FIXME ssh still uses files
    systemd.services.sssd-kcm.serviceConfig.ExecStart =
      lib.mkForce "${pkgs.sssd}/libexec/sssd/sssd_kcm";

    # TODO: passkey support
    services.sssd = {
      enable = true;
      settings = {
        sssd = {
          services = "nss, pam";
          domains = realm;
        };
        "domain/${realm}" = {
          id_provider = "ldap";
          ldap_uri = ldapURI;
          ldap_search_base = ldapBase;
          ldap_user_search_base = "ou=people," + ldapBase;
          ldap_group_search_base = "ou=group," + ldapBase;
          ldap_tls_reqcert = "hard";
          ldap_tls_cacert = "/etc/ssl/certs/ca-certificates.crt";

          auth_provider = "krb5";
          krb5_realm = realm;
          krb5_server = kdc;
          krb5_validate = hasKeytab;
          krb5_keytab = lib.mkIf hasKeytab keytabPath;
          krb5_use_rdns = false;

          # FIXME this is probably bad... pac_present seems to stop this error from appearing
          # we do not use active directory
          # https://github.com/SSSD/sssd/issues/8300#issuecomment-3655101429
          # [krb5_child[1489]] [sss_extract_pac] (0x0040): [RID#13] No PAC authdata available.
          # [krb5_child[1489]] [validate_tgt] (0x0040): [RID#13] sss_extract_and_send_pac failed, group membership for user with principal [guser@OCF.BERKELEY.EDU] might not be correct.
          pac_check = "pac_present";
        };
      };
    };

    users = {
      mutableUsers = false;
      users.root.hashedPasswordFile = config.age.secrets.root-password-hash.path;
    };

    environment.etc."ldap/ldap.conf".text = ''
      URI ${ldapURI}
      BASE ${ldapBase}
      TLS_REQCERT hard
      TLS_CACERT /etc/ssl/certs/ca-certificates.crt
      NETWORK_TIMEOUT 1
      TIMEOUT 60
      TIMELIMIT 60
      BIND_TIMELIMIT 1
    '';

    environment.variables.LDAPCONF = "/etc/ldap/ldap.conf";

    environment.etc."ldapvi.conf".text = ''
      profile default
      ldap-conf: yes
      sasl-mech: GSSAPI
      bind: sasl
    '';

    security.sudo = {
      extraConfig = ''
        Defaults passprompt="[sudo] password for %u/root: "
      '';

      extraRules = [
        {
          groups = [ "ocfroot" ];
          commands = [ "ALL" ];
        }
        {
          users = [ "ocfbackups" ];
          commands = [
            {
              command = lib.getExe pkgs.rsync;
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };

    # TODO: migrate this to sssd
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

    # include kerberos cli tools and config but do not enable krb5 auth (we use sssd)
    security.pam.krb5.enable = false;
    security.krb5 = {
      enable = true;
      package = pkgs.heimdal;

      settings = {
        realms."${realm}" = {
          admin_server = kdc;
          kdc = [ kdc ];
        };
        domain_realm = {
          "${domain}" = realm;
          ".${domain}" = realm;
        };
        libdefaults = {
          default_realm = realm;
          default_ccache_name = "KCM:";
          rdns = false;
        };
      };
    };

    services.openssh.settings = {
      GSSAPIAuthentication = "yes";
      GSSAPICleanupCredentials = "yes";
      GSSAPIStrictAcceptorCheck = "yes";
      # ssh gssapi currently does not support a post-quantum safe key exchange
      # algorithm. lets disable gssapi key exchange and use ssh's default key
      # exchanges (which supports post-quantum safe key exchange).
      # Only enable key exchange if host has a keytab
      #GSSAPIKeyExchange = lib.mkIf hasKeytab "yes";
    };
  };
}
