{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ocf.zfs;
in
{
  options.ocf.zfs = {
    enable = lib.mkEnableOption "ZFS";
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.forceImportRoot = false;

    environment.systemPackages = with pkgs; [
      httm

      # syncoid/findoid are useful regardless of whether sanoid is used
      sanoid
    ];
  };
}
