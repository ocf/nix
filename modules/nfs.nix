{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ocf.nfs;

  # should be ok to put here since nix lazy evals
  homePath = if cfg.asRemote then "/remote" else "/home";
  nfsOpts = lib.flatten [
    "rw"
    "noatime"
    "nodev"
    "nosuid"

    "sync"
    "vers=4.2" # force version 4.2
    "bg" # mount in background and continue booting
    "timeo=150" # 15s timeout instead of default 60s
    "retrans=3"
    "nconnect=8" # 8 connections instead of 1

    (lib.optional cfg.kerberos "sec=krb5p")
    (lib.optional cfg.cache "fsc")
    (lib.optional cfg.softerr "softerr")
  ];
in
{
  options.ocf.nfs = {
    enable = lib.mkEnableOption "Enable NFS Mounts (NFS client)";

    # /services is necessary for remote homes since ~/public_html is a symlink
    # to /services

    mount = lib.mkOption {
      type = lib.types.bool;
      description = "Mount /services and /home from NFS.";
      default = true;
    };

    asRemote = lib.mkOption {
      type = lib.types.bool;
      description = "Mount NFS homes to /remote instead of /home (for desktops which create home directory in tmpfs on login).";
      default = false;
    };

    kerberos = lib.mkEnableOption "Whether to use Kerberos krb5p";
    cache = lib.mkEnableOption "Whether to use cachefilesd and FS-Cache";
    softerr = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to use softerr";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "nfs" ];
    services.cachefilesd.enable = cfg.cache;

    fileSystems = lib.mkIf cfg.mount {
      "/services" = {
        device = "services:/services";
        fsType = "nfs4";
        options = nfsOpts;
      };

      "${homePath}" = {
        device = "homes:/home";
        fsType = "nfs4";
        options = nfsOpts;
      };
    };
  };
}
