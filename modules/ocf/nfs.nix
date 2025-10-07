{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.nfs;
in
{
  options.ocf.nfs = {
    enable = lib.mkEnableOption "Enable NFS Mounts";

    mountHome = lib.mkOption {
      type = lib.types.bool;
      description = "Mount /home from NFS.";
      default = false;
    };

    mountServices = lib.mkOption {
      type = lib.types.bool;
      description = "Mount /services from NFS.";
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "nfs" ];

    fileSystems."/home" = lib.mkIf cfg.mountHome {
      device = "homes:/home";
      fsType = "nfs4";
      options = [ "rw" "bg" "noatime" "nodev" "nosuid" ];
    };

    fileSystems."/services" = lib.mkIf cfg.mountHome {
      device = "services:/services";
      fsType = "nfs4";
      options = [ "rw" "bg" "noatime" "nodev" "nosuid" ];
    };
  };
}
