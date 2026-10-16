{
  config,
  lib,
  ...
}:

let
  cfg = config.ocf.prometheus-export;
in
{
  options.ocf.prometheus-export = {
    enable = lib.mkEnableOption "exporting prometheus data";
    textFileDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/node_exporter/textfile_collector";
    };
    exporters = lib.mkOption {
      default = { };
      type = lib.types.attrsOf lib.types.submodule {
        enable = lib.mkEnableOption "running this exporter";
        script = lib.mkOption {
          type = lib.types.package;
          description = "the script to execute, the textfile to write is passed as argv[1]";
        };
        interval = lib.mkOption {
          type = lib.types.str;
          description = "how often to run the script, use systemd format (ex: '5s')";
          default = "5s";
        };
        serviceName = lib.mkOption {
          type = lib.types.str;
        };
      };
    };
  };

  config = lib.mkMerge [
    lib.mkIf
    cfg.enable
    (
      lib.mkMerge (
        lib.mapAttrsToList (
          name: exporter:
          let
            serviceName = "prometheus-textfile-exporter-${name}";
          in
          {
            cfg.exporters."${name}".serviceName = serviceName;
            systemd.services."${serviceName}" = {
              enable = true;
              after = [ "network.target" ];
              wants = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "oneshot";
                User = "root";
                ExecStart = "${lib.getExe exporter.script} ${cfg.textFileDir}/${name}.prom";
              };
            };
            systemd.timers."${serviceName}" = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnUnitActiveSec = exporter.interval;
                AccuracySec = "1ms";
                Unit = "${serviceName}.service";
              };
            };
          }
        ) cfg.exporters
      )
      // {
        systemd.tmpfiles.rules = [
          "d ${cfg.textFileDir} 0755 root root -"
        ];

        services.prometheus = {
          exporters = {
            node = {
              enable = true;
              port = 9100;
              openFirewall = true;
              enabledCollectors = [
                "systemd"
                "textfile"
                "ethtool"
                "softirqs"
                "tcpstat"
                "wifi"
              ];
              extraFlags = [
                "--collector.textfile.directory=${cfg.textFileDir}"
              ];
            };
          };
        };
      }
    )
  ];
}
