{ pkgs, ... }:

# This is a 1:1 copy of the old puppet setup. There's probably a better way to do this with nix
# (see services.sanoid and services.syncoid), but to avoid breaking backups we're doing it this
# way for now.
# 
# FIXME: Rewrite this to use a more nixos-style configuration setup.
{
  # TODO(remove): This is a hack to get the old backup scripts to work.
  programs.nix-ld.enable = true;
  services.envfs.enable = true;

  environment.systemPackages = with pkgs; [
    sanoid # for sanoid and syncoid
    moreutils # for chronic
    zfstools # for zfs-auto-snapshot
  ];

  services.cron.enable = true;
  services.cron.systemCronJobs = [
    "00 03 * * * /etc/ocf_backup/backup-zfs.sh | tee -a /var/log/zfs-backup.log"
  ];

  environment.etc = {
    # rsync backup scripts
    "ocf_backup/backup-git".source = ./assets/backup-git;
    "ocf_backup/backup-mysql".source = ./assets/backup-mysql;
    "ocf_backup/backup-pgsql".source = ./assets/backup-pgsql;
    "ocf_backup/backup-zfs-logrotate".source = ./assets/backup-zfs-logrotate;

    # cron entrypoints
    "ocf_backup/backup-zfs.sh".source = ./assets/backup-zfs.sh;

    # rsnapshot configs
    "ocf_backup/rsnapshot-zfs-git.conf".source = ./assets/rsnapshot-zfs-git.conf;
    "ocf_backup/rsnapshot-zfs-mysql.conf".source = ./assets/rsnapshot-zfs-mysql.conf;
    "ocf_backup/rsnapshot-zfs-pgsql.conf".source = ./assets/rsnapshot-zfs-pgsql.conf;
    "ocf_backup/rsnapshot-zfs.conf".source = ./assets/rsnapshot-zfs.conf;
  };
}
