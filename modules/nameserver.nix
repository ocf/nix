{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  bindGroup = config.users.users.${bindUser}.group;
  bindUser = config.systemd.services.bind.serviceConfig.User;

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
      # TODO this should actually be https://github.com/ocf/puppet/blob/master/modules/ocf_ns/templates/named.conf.options.erb
      configFile = "/srv/dns/etc/named.conf.local";
    };

    systemd.services.rebuild-dns-from-ldap = {
      after = [ "network-online.target" ];
      path = [
        build-zones
        pkgs.bind
      ];
      script = ''
        cd "$(mktemp -d)"
        cp --no-preserve=mode -r ${inputs.ocf-dns}/{etc,templates} .
        sed -i /auto-dnssec/d etc/named.conf.local  # removed in bind 9.19.16
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
          "+${lib.getExe' pkgs.coreutils "cp"} --no-preserve=ownership -r /run/dns/etc /srv/dns/"
          "+${lib.getExe' pkgs.coreutils "chown"} -R ${bindUser}:${bindGroup} /srv/dns"
          "+${lib.getExe' pkgs.systemd "systemctl"} reload-or-restart bind.service"
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
