{ lib, config, pkgs, ... }:

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
      etc."p10k.zsh".source = ./p10k.zsh;

      systemPackages = with pkgs; [
        bash
        zsh
        fish
        xonsh
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
          source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
          source /etc/p10k.zsh
        '';
      };

      fish.enable = true;
      xonsh.enable = true;
    };

    users.defaultUserShell = pkgs.zsh;
  };
}
