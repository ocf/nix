{ config, lib, ... }:

let
  inherit (lib)
    concatMapStrings
    concatMapStringsSep
    concatStringsSep
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.ocf.nfs;
in
{
  options.ocf.nfs = {
    enable = mkEnableOption "NFS exports";
    exports = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            directory = mkOption {
              type = types.path;
            };
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
              description = "NFS options applied to all hosts";
              example = [ "rw" ];
              type = with types; listOf str;
            };
          };
        }
      );
    };
  };

  config = mkIf cfg.enable {
    services.nfs.server = {
      enable = true;
      # https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/5/html/deployment_guide/s1-nfs-server-config-exports
      exports = lib.traceValSeq (
        concatMapStrings (export: ''
          ${export.directory} \
            ${concatMapStringsSep " \\\n  " (
              host: "${host}(${concatStringsSep " " export.options})"
            ) export.hosts}
        '') cfg.exports
      );
    };
  };
}
