{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.auth;

  access_conf_base =
    ''
      # format: permission:users/groups:origins
      #
      -:(sorry):cron crond
      +:ALL:cron crond
      +:root:ALL
      +:ocfbackups:hal.ocf.berkeley.edu
      +:ocf-nix-deploy-user:spike.ocf.berkeley.edu
      +:(ocfroot):ALL
      +:(ocfstaff):ALL
      +:(sys):ALL
    '';
in
{
  options.ocf.auth = {
    enable = lib.mkEnableOption "Enable OCF authentication";
  };

  options.ocf.auth.extra_access_conf = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "Extra lines to be added to /etc/security/access.conf";
    default = [ ];
  };

  config = lib.mkIf cfg.enable {
    age.secrets.root-password-hash.rekeyFile = ../../secrets/master-keyed/root-password-hash.age;

    users = {
      mutableUsers = false;
      users.root.hashedPasswordFile = config.age.secrets.root-password-hash.path;

      ldap = {
        enable = true;
        server = "ldaps://ldap.ocf.berkeley.edu";
        base = "dc=OCF,dc=Berkeley,dc=EDU";
        daemon.enable = true;
      };
    };

    environment.etc."openldap/ldap.conf".text = 
      ''
        uri ldaps://ldap.ocf.berkeley.edu
        tls_reqcert hard
        tls_cacert /etc/ssl/certs/ca-certificates.crt

        base dc=ocf,dc=berkeley,dc=edu
        nss_base_passwd ou=people,dc=ocf,dc=berkeley,dc=edu
        nss_base_group  ou=group,dc=ocf,dc=berkeley,dc=edu
      '';

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

    # TODO
    environment.etc."security/access.conf".text = if (lib.length (cfg.extra_access_conf) == 0) then access_conf_base + "-:ALL:ALL\n"
      else access_conf_base + (lib.concatStringsSep "\n" cfg.extra_access_conf) + "\n-:ALL:ALL\n";

    security.pam.services.login.rules.account.pam_access = {
      enable = true;
      control = "required";
      modulePath = "${pkgs.linux-pam}/lib/security/pam_access.so";
      order = config.security.pam.services.login.rules.account.ldap.order - 10;
      args = [ "accessfile=/etc/security/access.conf" ];
    };

    security.pam.services.sshd.rules.account.pam_access = {
      enable = true;
      control = "required";
      modulePath = "${pkgs.linux-pam}/lib/security/pam_access.so";
      order = config.security.pam.services.sshd.rules.account.ldap.order - 10;
      args = [ "accessfile=/etc/security/access.conf" ];
    };
  };
}
