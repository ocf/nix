{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.ldapServer;
  fqdn = "${config.networking.hostName}.ocf.berkeley.edu";
  ldapKeytabPath = ../../secrets/master-keyed/ldap-keytab.age;
  hasLdapKeytab = builtins.pathExists ldapKeytabPath;
  certDir = "/var/lib/acme/${fqdn}";

  ldapLint = pkgs.writeShellScriptBin "ldap-lint" ''
    exec ${
      pkgs.python312.withPackages (ps: [
        ps.ocflib
        ps.dnspython
      ])
    }/bin/python3 \
      ${./ldap-lint.py} "$@"
  '';
in
{
  options.ocf.ldapServer = {
    enable = lib.mkEnableOption "OCF OpenLDAP server";
  };

  config = lib.mkIf cfg.enable {
    # Keytab for the ldap/<hostname>@OCF.BERKELEY.EDU service principal.
    # The path is exposed to slapd via the KRB5_KTNAME environment variable.
    # Only configured if the keytab secret exists (not available until KDC is initialized).
    age.secrets.ldap-keytab = lib.mkIf hasLdapKeytab {
      rekeyFile = ldapKeytabPath;
      path = "/etc/openldap/ldap.keytab";
      owner = "openldap";
      group = "openldap";
      mode = "0400";
    };

    # slapd process runs as openldap user and needs to read acme certs, but acme certs are owned by acme user and acme group by default.
    security.acme.certs.${fqdn}.group = lib.mkDefault "openldap";

    # Cyrus SASL configuration for slapd GSSAPI authentication.
    # The keytab path comes from KRB5_KTNAME in the service environment, not here.
    environment.etc."sasl2/slapd.conf" = {
      text = ''
        mech_list: GSSAPI
        pwcheck_method: saslauthd
      '';
      mode = "0444";
    };

    # TODO: try removing, not sure if this is necessary, but it was present in the ocf_ldap puppet module... not moving yet for this migration from puppet to nix
    services.saslauthd = {
      enable = true;
      mechanism = "kerberos5";
    };

    services.openldap = {
      enable = true;
      # ldaps only — no unencrypted ldap://
      urlList = [ "ldaps:///" ];
      settings = {
        attrs = {
          olcLogLevel = [ "0" ];

          # TLS — cert issued for ${fqdn} with ldap.ocf.berkeley.edu as a SAN
          olcTLSCACertificateFile = "/etc/ssl/certs/ca-certificates.crt";
          olcTLSCertificateFile = "${certDir}/cert.pem";
          olcTLSCertificateKeyFile = "${certDir}/key.pem";
          olcTLSVerifyClient = "never";
          # OpenSSL cipher string (NixOS OpenLDAP uses OpenSSL, not GnuTLS)
          olcTLSCipherSuite = "HIGH:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK";

          # SASL/GSSAPI realm — map Kerberos principals to LDAP DNs
          olcSaslRealm = "OCF.BERKELEY.EDU";
          olcAuthzRegexp = [
            # Regular users → their ou=People entry
            "{0}uid=([^,/]+),cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth uid=$1,ou=People,dc=OCF,dc=Berkeley,dc=EDU"
            # Hosts → their ou=Hosts entry
            "{1}uid=host/([^,/]+)\\.ocf\\.berkeley\\.edu,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth cn=$1,ou=Hosts,dc=OCF,dc=Berkeley,dc=EDU"
          ];
        };

        # TODO: once all debian hosts deployed to with puppet are deprecated, remove puppet.schema.ldif
        children = {
          "cn=schema" = {
            includes = [
              "${pkgs.openldap}/etc/schema/core.ldif"
              "${pkgs.openldap}/etc/schema/cosine.ldif"
              "${pkgs.openldap}/etc/schema/nis.ldif"
              ./puppet.schema.ldif
              ./ocf.schema.ldif
            ];
          };

          "olcDatabase={0}config" = {
            attrs = {
              objectClass = [ "olcDatabaseConfig" ];
              olcDatabase = "{0}config";
              # Only local root (via SASL EXTERNAL) may modify cn=config
              olcAccess = [
                "{0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break"
              ];
            };
          };

          "olcDatabase={1}mdb" = {
            attrs = {
              objectClass = [
                "olcDatabaseConfig"
                "olcMdbConfig"
              ];
              olcDatabase = "{1}mdb";
              olcDbDirectory = "/var/lib/openldap/data";
              olcSuffix = "dc=OCF,dc=Berkeley,dc=EDU";
              # No rootDN password — all admin access is via SASL/GSSAPI
              olcSizeLimit = "-1";
              olcDbMaxSize = "2147483648"; # 2 GiB
              olcDbIndex = [
                "objectClass eq"
                "uid,uidNumber eq"
                "memberUid,uniqueMember eq"
                "cn eq,sub"
                "calnetUid,oslGid,callinkOid eq,pres"
              ];

              # Note: the puppet slapd used ocf/ldap-overlay to synthesize
              # ocfEmail dynamically from uid (for some reason?). since
              # migrating from puppet to nix, we now store ocfEmail directly on
              # user entries and populate by ocflib on account
              # creation/modification (see ocfweb).

              # ocfEmail is only currently used in the rt and waddles (ai
              # chatbot) repos anyway, no real reason for it to exist. may
              # delete soon anyway.

              olcAccess = [
                # Root DSE is readable by everyone
                "{0}to dn.base=\"\" by * read"
                # Only /admin (with GSSAPI) can write userPassword; owner can read; anonymous can auth
                "{1}to dn.subtree=\"ou=People,dc=OCF,dc=Berkeley,dc=EDU\" attrs=userPassword by sasl_ssf=56 dn.regex=\"^uid=[^,/]+/admin,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth$\" write by sasl_ssf=56 self read by sasl_ssf=56 anonymous auth by * none"
                # Hosts can update their own puppet environment; /admin can write; users can read over SSL
                "{2}to dn.subtree=\"ou=Hosts,dc=OCF,dc=Berkeley,dc=EDU\" attrs=environment by sasl_ssf=56 dn.regex=\"^uid=[^,/]+/admin,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth$\" write by sasl_ssf=56 self write by sasl_ssf=56 users read by tls_ssf=256 anonymous read"
                # Sorried users cannot change their own shell
                "{3}to dn.subtree=\"ou=People,dc=OCF,dc=Berkeley,dc=EDU\" filter=(loginShell=/opt/share/utils/bin/sorried) attrs=loginShell by sasl_ssf=56 dn.regex=\"^uid=[^,/]+/admin,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth$\" write by sasl_ssf=56 users read by tls_ssf=256 anonymous read"
                # Non-sorried users can change their own shell

                "{4}to dn.subtree=\"ou=People,dc=OCF,dc=Berkeley,dc=EDU\" attrs=loginShell by sasl_ssf=56 dn.regex=\"^uid=[^,/]+/admin,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth$\" write by sasl_ssf=56 self write by sasl_ssf=56 users read by tls_ssf=256 anonymous read"
                # mail: /admin and /root can read; smtp service can read; owner can write
                "{5}to dn.subtree=\"ou=People,dc=OCF,dc=Berkeley,dc=EDU\" attrs=mail by sasl_ssf=56 dn.regex=\"^uid=[^,/]+/admin,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth$\" write by sasl_ssf=56 dn.regex=\"^uid=[^,/]+/root,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth$\" read by sasl_ssf=56 dn=\"uid=smtp/anthrax.ocf.berkeley.edu,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth\" read by sasl_ssf=56 self write by * none"
                # Everything else: /admin can write; authenticated users can read over GSSAPI; anonymous can read over TLS
                "{6}to * by sasl_ssf=56 dn.regex=\"^uid=[^,/]+/admin,cn=OCF.BERKELEY.EDU,cn=GSSAPI,cn=auth$\" write by sasl_ssf=56 users read by tls_ssf=256 anonymous read"
              ];
            };
          };
        };
      };
    };

    systemd.services.openldap = {
      serviceConfig = {
        # Point slapd at the GSSAPI keytab
        Environment = "KRB5_KTNAME=/etc/openldap/ldap.keytab";
      };
    };

    # KDC must start after slapd so SASL/GSSAPI is available for KDC → LDAP lookups
    systemd.services.krb5kdc.after = [ "openldap.service" ];

    environment.systemPackages = [ ldapLint ];

    networking.firewall.allowedTCPPorts = [ 636 ];

    systemd.tmpfiles.rules = [
      "d /var/lib/openldap/data 0700 openldap openldap -"
      "d /etc/openldap 0750 openldap openldap -"
      "d /var/backups/ldap 0700 root root -"
    ];

    # SSH deploy key for pushing the LDAP backup to github.com:ocf/ldap
    age.secrets.ldap-github-deploy-key = {
      rekeyFile = ../../secrets/master-keyed/eel/ldap-github-deploy-key.age;
      path = "/root/.ssh/id_rsa_ldap_backup";
      owner = "root";
      group = "root";
      mode = "0600";
    };

    # Pin GitHub's host key so the backup push doesn't need to prompt
    programs.ssh.knownHosts."github.com" = {
      publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
    };

    systemd.services.ldap-git-backup = {
      description = "LDAP git backup";
      after = [ "openldap.service" ];
      requires = [ "openldap.service" ];
      path = [
        pkgs.ldap-git-backup
        pkgs.openldap
        pkgs.git
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        UMask = "0077";
      };
      environment = {
        GIT_SSH_COMMAND = "ssh -i ${config.age.secrets.ldap-github-deploy-key.path}";
      };
      script = ''
        ldap-git-backup --backup-dir /var/backups/ldap \
          --ldif-cmd "${pkgs.openldap}/bin/slapcat"
        git -C /var/backups/ldap push -q git@github.com:ocf/ldap master
      '';
    };

    systemd.timers.ldap-git-backup = {
      description = "Run LDAP git backup daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # Run before rsnapshot so the backup server gets a fresh daily snapshot
        OnCalendar = "*-*-* 01:00:00";
        Persistent = true;
      };
    };
  };
}
