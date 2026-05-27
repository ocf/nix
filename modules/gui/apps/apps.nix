{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.gui.apps;
in
{
  options.ocf.gui.apps.enable = lib.mkEnableOption "Enable development related apps";

  config = lib.mkIf cfg.enable {
    hardware.graphics.enable32Bit = true;

    programs.steam.enable = true;
    programs.steam.protontricks.enable = true;

    programs.zoom-us.enable = true;
    programs.obs-studio.enable = true;
    programs.obs-studio.enableVirtualCamera = true;

    programs.thunderbird.enable = true;
    # FIXME: cosmic files does not read the multiple mimeapps.list files
    # correctly, but it does correctly read the one in XDG_CONFIG_HOME. thus,
    # mimeapps.list is stored in skel until this is fixed.
    #xdg.mime.defaultApplications."x-scheme-handler/mailto" = "thunderbird.desktop";

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

      # controller support
      antimicrox

      # GAMES
      dwarf-fortress
      unciv
      supertuxkart
      tetris

      # emulators
      dosbox
      dolphin-emu
      ryubing

      # minecraft
      prismlauncher
      worldpainter
      amidst
      mcaselector

      # windows compat
      lutris
      bottles
      winetricks
      wineWow64Packages.stable

      # extra terminal emulators
      alacritty
      st
      ghostty

      yubioath-flutter
      kdiskmark
      remmina

      zenmap
      wireshark

      cobang

      # IRC Clients
      hexchat
      halloy

      element-desktop

      # pipewire
      easyeffects
      helvum

      mission-center
      kana
      freerdp
      zotero

      # password managers
      bitwarden-desktop
      _1password-gui
    ];
  };
}
