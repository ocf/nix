{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.printhost;

  pythonEnv = pkgs.python312.withPackages (ps: with ps; [
    pycups
    prometheus-client
  ]);

  monitorScriptPy = pkgs.writeTextFile {
    name = "monitor-cups.py";
    text = builtins.readFile ./scripts/monitor-cups.py;
  };

  monitorBin = pkgs.writeShellScript "monitor-cups" ''
    exec ${pythonEnv}/bin/python3 ${monitorScriptPy} "$@"
  '';

in
{
  config = lib.mkIf cfg.enable {

    systemd.tmpfiles.rules = [
      "d /srv/prometheus 0755 root root -"
    ];

    systemd.services.monitor-cups = {
      description = "CUPS metrics exporter for Prometheus";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${monitorBin} /srv/prometheus/cups.prom";
      };
      environment = {
        PYTHONUNBUFFERED = "1";
      };
    };

    systemd.timers.monitor-cups = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
      };
    };
  };
}
