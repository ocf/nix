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
    "nconnect=8" # 8 connections instead of 1

    (lib.optional cfg.kerberos "sec=krb5p")
    (lib.optional cfg.cache "fsc")

    # - hard will retry indefinitely.
    # - softerr will retry retrans number of times with timeo seconds between
    #   each attempt before returning an io error (per rpc request).
    # - softerr prioritizes responsiveness, and should rapid fire the retries
    #   so that a minor hiccup doesnt turn into a minute long freeze. however,
    #   hard should have a longer timeout so that it doesnt spam the nfs server
    #   indefinitely for every rpc request. for example, on a desktop system
    #   where nfs is not critical to everything working, if nfs did not respond
    #   in 15 seconds, freezing the file browser is more frustrating than it is
    #   worth.
    # - hard should be used on hosts where the nfs mount is critical to the
    #   entire functionality of the system, and it makes sense to just hang write
    #   requests and flush them when the nfs server is back up. hard is also
    #   preferable for data integrity.
    (
      if cfg.softerr then
        [
          # retry 4 times, 2s timeout each
          "timeo=20"
          "retrans=4"
          "softerr"
        ]
      else
        [
          # retry 3 times, 30s timeout each
          "timeo=300"
          "retrans=3"
          "hard"
        ]
    )
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
