{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.cli;
in
{
  options.ocf.cli = {
    enable = lib.mkEnableOption "shell configuration";
    shells = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = ''
        Shells to install and symlink to /bin and /usr/bin. Needed for LDAP logins.

        - envfs is very unreliable, and leaves systems completely deadlocked when
          it fails, requiring you to run `echo "1" > /sys/fs/fuse/*/connections/abort`
          to unfreeze the system. this is absolutely unacceptable and has happened
          many times on our login servers.
        - having a flat file instead of a fuse filesystem should be far more
          reliable, especially for critical directories like /usr/bin and /bin.
        - loginShell attributes in our ldap are set to /usr/bin. we want to
          continue supporting other linux distributions, and using a non-absolute
          path for a login shell is questionable.
      '';
      # list partly pulled from ocflib/misc/validators.py
      default = with pkgs; [
        # FIXME: recompiles bash lol
        #(bash.overrideAttrs (old: { meta = old.meta // { mainProgram = "sh"; }; }))
        dash
        bash
        screen
        tmux
        zsh
        tcsh
        fish
        xonsh
        ksh
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.shells.text = lib.concatMapStringsSep "" (
      shell:
      let
        execName = shell.meta.mainProgram or shell.pname;
      in
      # let system.activationScripts.binsh and usrbinenv handle these
      lib.optionalString (execName != "sh") ''
        ln -sf '${lib.getExe shell}' /bin/
      ''
      + lib.optionalString (execName != "env") ''
        ln -sf '${lib.getExe shell}' /usr/bin/
      ''
    ) cfg.shells;

    environment = {
      enableAllTerminfo = true;

      systemPackages =
        with pkgs;
        [
          zsh-powerlevel10k
        ]
        ++ cfg.shells;
    };

    programs = {
      zsh = {
        enable = true;
        shellInit = ''
          zsh-newuser-install() { :; }
        '';
        interactiveShellInit = ''
          # add default ocf config only if not disabled by user in ~/.zshenv by
          # setting $SKIP_OCF_ZSHRC
          if [[ -n "$SKIP_OCF_ZSHRC" ]]; then
            return
          fi

          # emacs keybinds: ^u, ^k, ^a, ^e, etc
          # this is a good nonintrusive default that adds useful keybinds while
          # not interfering with people's muscle memory
          bindkey -e

          source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

          # p10k.zsh start
          ${builtins.readFile ./p10k.zsh}
          # p10k.zsh end

          # command_not_found_handler.zsh start
          ${builtins.readFile ./command_not_found_handler.zsh}
          # command_not_found_handler.zsh end
        '';
      };

      fzf.keybindings = true;
      fzf.fuzzyCompletion = true;

      fish.enable = true;
      xonsh.enable = true;
    };

    users.defaultUserShell = pkgs.zsh;
  };
}
