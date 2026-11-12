{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ocf.rsnapshot;

  replaceCmds = file: pkgs.replaceVars file {
    cp = lib.getExe' pkgs.coreutils "cp";
    rm = lib.getExe' pkgs.coreutils "rm";
    rsync-no-vanished = lib.getExe rsync-no-vanished;
    ssh = lib.getExe pkgs.openssh;
    logger = lib.getExe' pkgs.inetutils "logger";
    #ocfbackups-keytab = TODO
    kinit = lib.getExe' config.security.krb5.package "kinit";
    kdestroy = lib.getExe' config.security.krb5.package "kdestroy";
  };

  rsync-no-vanished = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "rsync-no-vanished";
    inherit (pkgs.rsync) version src;
    postPatch = ''
      cd support
      substituteInPlace rsync-no-vanished \
        --replace-fail 'REAL_RSYNC=/usr/bin/rsync' 'REAL_RSYNC=${lib.getExe pkgs.rsync}'
    '';
    dontBuild = true;
    installPhase = ''
      install -Dt "$out/bin" rsync-no-vanished
    '';
    meta.mainProgram = "rsync-no-vanished";
  });

  zfs-auto-snapshot = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "zfs-auto-snapshot";
    version = "1.2.4";
    src = pkgs.fetchFromGitHub {
      owner = "zfsonlinux";
      repo = "zfs-auto-snapshot";
      tag = "upstream/${finalAttrs.version}";
      hash = "sha256-2O1NjFelumZCfk3wk7OHh5bM7hlh8eTaL3ZRXODhnVQ=";
    };
    makeFlags = [
      "DESTDIR=${placeholder "out"}"
      "PREFIX="
    ];
  });
in
{
  options.ocf.rsnapshot = {
    enable = lib.mkEnableOption "";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.rsnapshot-daily = {
      path = with pkgs; [
        rsnapshot
        sanoid
        zfs-auto-snapshot
      ];
      script = ''
        CURRENT_SNAPSHOT_FILE=/opt/share/backups/current-zfs-snapshot
        CURRENT_SNAPSHOT=$(cat $CURRENT_SNAPSHOT_FILE)
        OFFSITE_HOST=$(cat /opt/share/backups/offsite-host)
        echo "$CURRENT_SNAPSHOT"

        rsnapshot -c ${replaceCmds ./rsnapshot-zfs.conf} sync
        rsnapshot -c ${replaceCmds ./rsnapshot-zfs-mysql.conf} sync
        rsnapshot -c ${replaceCmds ./rsnapshot-zfs-git.conf} sync

        zfs-auto-snapshot --syslog --label=after-backup --keep=100 // | awk -F"," '{print $1}' | cut -c2- > $CURRENT_SNAPSHOT_FILE
        NEW_SNAPSHOT=$(cat $CURRENT_SNAPSHOT_FILE)

        echo "$CURRENT_SNAPSHOT"
        echo "$NEW_SNAPSHOT"

        syncoid -r --no-sync-snap --sendoptions "L w c" backup/encrypted/rsnapshot "$OFFSITE_HOST":data1/ocfbackup/encrypted/rsnapshot
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };

    systemd.timers.rsnapshot-daily = {
      timerConfig = {
        OnCalendar = "03:00";
      };
    };
  };
}
