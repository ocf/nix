# development related apps for ocf desktops

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.gui;
in
{
  options.ocf.gui.apps.dev.enable = lib.mkOption {
    type = lib.types.bool;
    description = "Enable development related apps";
    default = cfg.enable && cfg.extra;
  };

  config = lib.mkIf cfg.apps.dev.enable {
    environment.systemPackages = with pkgs; [
      # gui editors
      vscode-fhs
      vscodium-fhs
      # uncomment once electron version is updated to non eol
      # https://github.com/ocf/nix/pull/244
      #rstudio
      zed-editor
      gnome-builder
      jetbrains.idea-oss
      jetbrains.pycharm-oss
      jetbrains.datagrip

      # git
      gitg
      github-desktop
      gitFull # has gitk
      mercurialFull # has hgk

      meld
      insomnia
    ];
  };
}
