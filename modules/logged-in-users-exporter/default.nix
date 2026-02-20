{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.ocf.logged-in-users-exporter;
in
{
  options.ocf.logged-in-users-exporter = {
    enable = mkEnableOption "Enable logged in users exporter for Prometheus (used by OCF Labmap)";
    interval = mkOption {
      type = types.int;
      default = 5;
    };
  };

  config = mkIf cfg.enable {
    environment.etc = {
      "prometheus_scripts/logged_in_users_exporter.sh" = {
        mode = "0555";
        text = builtins.readFile ./logged_in_users_exporter.sh;
      };
    };

    # Create the textfile collector directory
    systemd.tmpfiles.rules = [
      "d /var/lib/node_exporter/textfile_collector 0755 root root -"
      "d /etc/prometheus_scripts 0755 root root -"
      "z /etc/prometheus_scripts/logged_in_users_exporter.sh 0755 root root -"
    ];

    systemd.services."logged_in_users_exporter" = {
      enable = true;
      description = "Logged in users exporter";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Environment = "PATH=/run/current-system/sw/bin";
        ExecStart = "/etc/prometheus_scripts/logged_in_users_exporter.sh";
      };
    };

    services.prometheus = {
      exporters = {
        node = {
          enable = true;
          port = 9100;
          enabledCollectors = [ "systemd" "textfile" ];
          extraFlags = [ "--collector.ethtool" "--collector.softirqs" "--collector.tcpstat" "--collector.wifi" "--collector.textfile.directory=/var/lib/node_exporter/textfile_collector" ];
        };
      };
    };
  };
}
