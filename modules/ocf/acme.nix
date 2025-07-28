{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.acme;
in
{
  options.ocf.acme = {
    enable = lib.mkEnableOption "Enable OCF ACME";
    extraCerts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Additional domains to add to cert";
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {

    age.secrets.tsig-secret.rekeyFile = ../../secrets/master-keyed/tsig-secret.age;

    security.acme = {

      acceptTerms = true;

      defaults = {
        enableDebugLogs = true;
        email = "root@ocf.berkeley.edu";
        dnsProvider = "rfc2136";
        credentialFiles = {
          "RFC2136_NAMESERVER_FILE" = pkgs.writeText "name-server" "169.229.226.22";
          "RFC2136_TSIG_KEY_FILE" = pkgs.writeText "tsig-key" "letsencrypt.ocf.io";
          "RFC2136_TSIG_ALGORITHM_FILE" = pkgs.writeText "tsig-algo" "hmac-sha512";
          "RFC2136_TSIG_SECRET_FILE" = config.age.secrets.tsig-secret.path;
        };
      };

      certs."${config.networking.hostName}.ocf.berkeley.edu" = {
        domain = "${config.networking.hostName}.ocf.berkeley.edu";
        extraDomainNames = [ "${config.networking.hostName}.ocf.io" ] ++ cfg.extraCerts;
      };
    };
  };
}
