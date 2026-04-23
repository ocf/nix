{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.home;
  tmpfsScript = pkgs.writeShellScript "ocf_tmpfs_skel" (builtins.readFile ./ocf_tmpfs_skel.sh);
  mountRemoteScript = pkgs.writeShellScript "ocf_mount_remote" (
    builtins.readFile ./ocf_mount_remote.sh
  );
  remoteHost = "ssh";
in
{
  options.ocf.home = {
    tmpfs = lib.mkEnableOption "mount tmpfs on /home and each user's home directory (unmounted on logout)";
    mountRemote = lib.mkOption {
      type = lib.types.bool;
      default = config.ocf.nfs.mount && config.ocf.nfs.asRemote;
      description = "nfs mount ~/remote, copy skel from remote on login if it exists";
    };
  };

  assertions = lib.mkIf cfg.mountRemote lib.singleton {
    assertion = config.ocf.nfs.mount && config.ocf.nfs.asRemote;
    message = "ocf.home.mountRemote requires ocf.home.tmpfs and nfs mounted /remote and /services";
  };

  config = lib.mkIf cfg.tmpfs {
    fileSystems."/home" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "size=16G"
        "mode=755"
      ];
    };

    security.pam = {
      # Trim spaces from username
      services.login.rules.auth.trimspaces = {
        control = "requisite";
        modulePath = "${pkgs.ocf-pam_trimspaces}/lib/security/pam_trimspaces.so";
        order = 0;
      };

      # mount ~ as tmpfs
      services.login.pamMount = true;
      mount.extraVolumes = [
        ''<volume fstype="tmpfs" path="tmpfs" mountpoint="~" options="uid=%(USERUID),gid=%(USERGID),mode=0700"/>''
      ];

      # because mount now creates the home dir and mounts tmpfs on it,
      # mkhomedir wont copy the skel because the dir exists. we can copy skel
      # as part of a home setup script, and do other stuff as well

      services.login.rules.session =
        let
          cfgPam = config.security.pam.services.login.rules.session;
        in
        {
          # needed to mount ~/remote with kerberos auth
          mount.order = cfgPam.krb5.order + 50;
          ocf_home_setup = {
            order = cfgPam.mount.order + 50;
            control = "optional";
            modulePath = "pam_exec.so";
            args = [ if cfg.mountRemote then "${mountRemoteScript}" else "${tmpfsScript}" ];
          };
        };
    };
  };
}
