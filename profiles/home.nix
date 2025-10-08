{ lib, config, pkgs, inputs, ... }:

#let
#  username = builtins.getEnv "USER";
#  homedir = "/home/${builtins.subString 0 1 username}/${builtins.subString 0 2 username}/${username}";
#in
{
  gtk.font.size = 32;
  home.stateVersion = "25.05";
#  home.username = "jaysa";
#  home.homeDirectory = "/home/j/ja/jaysa";
#  home.username = username;
#  home.homeDirectory = homedir;

  programs = {
    kitty = {
      enable = true;
      themeFile = "gruvbox-dark-hard";
    };
  };

  programs.home-manager.enable = true;
}
