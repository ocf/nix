{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  build-zones = pkgs.stdenv.mkDerivation {
    name = "build-zones";
    src = inputs.ocf-dns;
    buildInputs = [
      (config.ocf.python.package.withPackages (ps: [
        ps.ldap3
        ps.ocflib
      ]))
    ];
    installPhase = ''
      install -Dt "$out/bin" build-zones check-zones
    '';
    meta.mainProgram = "build-zones";
  };

  cfg = config.ocf.nameserver;
in
{
  options.ocf.nameserver = {
    enable = lib.mkEnableOption "name server";
  };

  config = lib.mkIf cfg.enable {
    services.bind = {
      enable = true;
      configFile = "/srv/dns/etc/named.conf.local";
    };
    systemd.services.bind = {
      after = [ "rebuild-dns-from-ldap.service" ];
    };

    systemd.services.rebuild-dns-from-ldap = {
      after = [ "network-online.target" ];
      path = [
        build-zones
        pkgs.bind
      ];
      script = ''
        cd "$(mktemp -d)"
        cp -r ${inputs.ocf-dns}/. .
        build-zones
        check-zones
        cp -r etc /run/dns/
      '';
      serviceConfig = {
        DynamicUser = true;
        ExecStartPost = [
          # + runs the command as root
          "+${lib.getExe' pkgs.coreutils "mkdir"} -p /srv/dns/"
          # cannot use atomic `exch` for the next two operations because /run/dns is on a different fs (bind mount)
          "+${lib.getExe' pkgs.coreutils "rm"} -rf /srv/dns/etc"
          "+${lib.getExe' pkgs.coreutils "mv"} /run/dns/etc /srv/dns/"
          "+${lib.getExe' pkgs.systemd "systemctl"} reload bind.service"
        ];
        RuntimeDirectory = "dns";
        Type = "oneshot";
      };
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
    };

    systemd.timers.rebuild-dns-from-ldap = {
      timerConfig.OnCalendar = "hourly";
      wantedBy = [ "timers.target" ];
    };
  };
}
