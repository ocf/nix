{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.home;
  homeSetupScript = pkgs.writeShellScript "ocf_setup_home" (builtins.readFile ./ocf_setup_home.sh);
  remoteHost = "ssh";

  # Default openssh doesn't include GSSAPI support, so we need to override sshfs
  # to use the openssh_gssapi package instead. This is annoying because the
  # sshfs package's openssh argument is nested in another layer of callPackage,
  # so we override callPackage instead to override openssh.
  sshfs = pkgs.sshfs.override {
    callPackage =
      fn: args:
      (pkgs.callPackage fn args).override {
        openssh = pkgs.openssh_gssapi;
      };
  };
in
{
  options.ocf.home = {
    tmpfs = lib.mkEnableOption "mount tmpfs on /home and each user's home directory (unmounted on logout)";
    #TODO mountRemote = lib.mkEnableOption "sshfs mount ${remoteHost}:~ on ~/remote";
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

      services.login.pamMount = true;

      # needed to mount ~/remote with kerberos ssh auth
      services.login.rules.session.mount.order =
        config.security.pam.services.login.rules.session.krb5.order + 50;

      # mount ~ and ~/remote
      mount.extraVolumes = [
        ''<volume fstype="tmpfs" path="tmpfs" mountpoint="~" options="uid=%(USERUID),gid=%(USERGID),mode=0700"/>''
        # TODO: enable StrictHostKeyChecking and UserKnownHostsFile because these should not be disabled!
        #''<volume fstype="fuse" path="${lib.getExe sshfs}#%(USER)@${remoteHost}:" mountpoint="~/remote/" options="follow_symlinks,UserKnownHostsFile=/dev/null,StrictHostKeyChecking=no" pgrp="ocf" />''
      ];

      # because mount now creates the home dir and mounts tmpfs on it, mkhomedir wont copy the skel because the dir exists
      # we can do copy skel as part of a home setup script, and do other stuff as well
      #services.login.rules.session.mkhomedir.order = config.security.pam.services.login.rules.session.mount.order + 50;
      #makeHomeDir.skelDirectory = "/etc/skel";

      services.login.rules.session.ocf_home_setup = {
        order = config.security.pam.services.login.rules.session.mount.order + 50;
        control = "optional";
        modulePath = "pam_exec.so";
        args = [ "${homeSetupScript}" ];
      };
    };
  };
}
