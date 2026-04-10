{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.home;
  remoteHost = "tsunami";

  # Default openssh doesn't include GSSAPI support, so we need to override sshfs
  # to use the openssh_gssapi package instead. This is annoying because the
  # sshfs package's openssh argument is nested in another layer of callPackage,
  # so we override callPackage instead to override openssh.
  sshfs = pkgs.sshfs.override {
    callPackage = fn: args: (pkgs.callPackage fn args).override {
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
      options = [ "size=16G" "mode=755" ];
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
      services.login.rules.session.mount.order = config.security.pam.services.login.rules.session.krb5.order + 50;
      services.login.rules.session.mkhomedir.order = config.security.pam.services.login.rules.session.mount.order + 50;

      # mount ~ and ~/remote
      mount.extraVolumes = [
        ''<volume fstype="tmpfs" path="tmpfs" mountpoint="~" options="uid=%(USERUID),gid=%(USERGID),mode=0700"/>''
        # TODO: enable StrictHostKeyChecking and UserKnownHostsFile because these should not be disabled!
        ''<volume fstype="fuse" path="${lib.getExe sshfs}#%(USER)@${remoteHost}:" mountpoint="~/remote/" options="follow_symlinks,UserKnownHostsFile=/dev/null,StrictHostKeyChecking=no" pgrp="ocf" />''
      ];

      makeHomeDir.skelDirectory = "/etc/skel";
    };
  };
}
