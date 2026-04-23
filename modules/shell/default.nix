{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.shell;
in
{
  options.ocf.shell = {
    enable = lib.mkEnableOption "Enable shell configuration";
  };

  config = lib.mkIf cfg.enable {
    environment = {
      enableAllTerminfo = true;

      systemPackages = with pkgs; [
        bash
        zsh
        fish
        xonsh
        tcsh
        zsh-powerlevel10k
      ];
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
