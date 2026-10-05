{
  config,
  lib,
  ...
}:

let
  cfg = config.ocf.prometheus-export;

  makeExporter = script: {
    systemd.services."${script.name}" = {
      enable = true;
      description = "${script.name}";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };

      inherit script;
    };
    systemd.timers."${script.name}" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = "5s";
        AccuracySec = "1ms";
        Unit = "${script.name}.service";
      };
    };
  };
in
{
  options.ocf.prometheus-export = {
    enable = lib.mkEnableOption "exporting prometheus data";
    textFileDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/node_exporter/textfile_collector";
    };
    textFileScripts = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = [ ];
    };
  };

  config = lib.mkMerge [
    lib.mkIf
    cfg.enable
    (
      lib.mkMerge (map (script: makeExporter script) cfg.textFileScripts)
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
    {
      assertions = [
        {
          assertion = (cfg.textFileScripts != [ ]) && !cfg.enable;
          message = "ocf.prometheus-export must be enabled to enable an exporter";
        }
      ];
    }
  ];
}
