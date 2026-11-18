{
  config,
  lib,
  ...
}:

let
  cfg = config.ocf.impermanence;
in
{
  options.ocf.impermanence = {
    enable = lib.mkEnableOption "impermanence";
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/persist".neededForBoot = true;
    age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

    environment.persistence."/persist" = {
      directories = [
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/log"
      ];
      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_rsa_key"
      ];
    };

    boot.initrd.systemd.services.wipe-filesystems = {
      after = [
        "local-fs-pre.target"
        "zfs-import.target"
      ];
      before = [ "sysroot.mount" ];
      wantedBy = [ "initrd.target" ]; # use requiredBy if boot should fail without this
      requires = [ "zfs-import.target" ];
      script = ''
        zfs rollback -r zroot/root@blank
      '';
      serviceConfig.Type = "oneshot";
      unitConfig.DefaultDependencies = false;
    };
  };
}
