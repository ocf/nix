{ config, lib, ... }:

let
  inherit (lib)
    concatMapAttrsStringSep
    concatMapStringsSep
    concatStringsSep
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.ocf.nfs-export;
in
{
  options.ocf.nfs-export = {
    enable = mkEnableOption "NFS exports";
    exports = mkOption {
      type = types.attrsOf (
        types.nonEmptyListOf (
          types.submodule {
            options = {
              hosts = mkOption {
                description = "Hosts with which the export is shared";
                example = [
                  "192.168.0.0/28"
                  "*.ocf.io"
                ];
                type = with types; nonEmptyListOf str;
              };
              options = mkOption {
                default = [ ];
                description = "NFS options applied to the hosts";
                example = [ "rw" ];
                type = with types; listOf str;
              };
            };
          }
        )
      );
    };
  };

  config = mkIf cfg.enable {
    services.nfs.server = {
      enable = true;
      # https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/5/html/deployment_guide/s1-nfs-server-config-exports
      exports = concatMapAttrsStringSep "" (directory: hostsAndOptions: ''
        ${directory} \
          ${concatMapStringsSep " \\\n  " (
            { hosts, options }:
            concatMapStringsSep " \\\n  " (host: "${host}(${concatStringsSep "," options})") hosts
          ) hostsAndOptions}
      '') cfg.exports;
    };

    networking.firewall.allowedTCPPorts = [
      # sufficient for NFSv4
      2049
    ];
  };
}
