{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.acme;
in
{
  options.ocf.acme = {

    enable = lib.mkEnableOption "Enable OCF ACME";

    shortlived = lib.mkOption {
      type = lib.types.bool;
      description = "Enable Using Short Lived (6 Day) Certs";
      default = false;
    };

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

      defaults = lib.mkMerge [
        {
          enableDebugLogs = true;
          email = "root@ocf.berkeley.edu";
          dnsProvider = "rfc2136";
          # https://letsencrypt.org/docs/profiles/#tlsserver
          extraLegoRunFlags = [ "--profile" "tlsserver" ];
          extraLegoRenewFlags = [ "--profile" "tlsserver" ];
          credentialFiles = {
            "RFC2136_NAMESERVER_FILE" = pkgs.writeText "name-server" "169.229.226.22";
            "RFC2136_TSIG_KEY_FILE" = pkgs.writeText "tsig-key" "letsencrypt.ocf.io";
            "RFC2136_TSIG_ALGORITHM_FILE" = pkgs.writeText "tsig-algo" "hmac-sha512";
            "RFC2136_TSIG_SECRET_FILE" = config.age.secrets.tsig-secret.path;
          };
        }

        ( lib.mkIf cfg.shortlived {
            # TODO:  Currently still being rolled out and restriced to a allowlist so 
            # we can't request these certs but def worth moving over once it's available.

            # https://letsencrypt.org/2025/01/16/6-day-and-ip-certs/
            # https://letsencrypt.org/2025/02/20/first-short-lived-cert-issued/
            extraLegoRunFlags = lib.mkForce [ "--profile" "shortlived" ];
            extraLegoRenewFlags = lib.mkForce [ "--profile" "shortlived" ];

            # TODO: Remove this when Lego moves to v5 and uses --dynamic by default instead
            # of having to manually set --days. This will automatically renew shortlived 
            # certs in 3 days. https://go-acme.github.io/lego/usage/cli/options/index.html
            validMinDays = 3;
          }
        )
      ];

      certs."${config.networking.hostName}.ocf.berkeley.edu" = {
        domain = "${config.networking.hostName}.ocf.berkeley.edu";
        extraDomainNames = [ "${config.networking.hostName}.ocf.io" ] ++ cfg.extraCerts;
      };
    };
  };
}
