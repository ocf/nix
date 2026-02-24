{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.etc;
in
{
  options.ocf.etc = {
    enable = lib.mkEnableOption "Enable /etc/ocf configuration";
  };

  config = lib.mkIf cfg.enable {
    # Instead of populating /etc/ocf using `environment.etc`, we use a systemd
    # service to pull the repository every 15 minutes. This allows us to keep
    # the repository up to date without needing to update the NixOS config.
    systemd = {
      services.sync-etc = {
        description = "Update OCF etc repository";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.ocf-sync-etc}/bin/sync-etc /etc/ocf";
        };
      };

      timers.sync-etc = {
        description = "Update OCF etc repository";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/15";
          RandomizedDelaySec = "15m";
          FixedRandomDelay = true;
        };
      };
    };
  };
}
