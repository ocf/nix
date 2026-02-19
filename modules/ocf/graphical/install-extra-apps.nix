# preinstalled apps for ocf desktops

{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.graphical.install-extra-apps;
in
{
  options.ocf.graphical.install-extra-apps = lib.mkEnableOption "Install extra software useful for OCF lab desktops";

  config = lib.mkIf cfg {
    programs.steam.enable = true;
    programs.zoom-us.enable = true;
    programs.obs-studio.enable = true;
    programs.obs-studio.enableVirtualCamera = true;

    environment.systemPackages = with pkgs; [
      # extra terminal emulators
      alacritty
      st
      ghostty

      libreoffice
      drawio
      xournalpp
      octave
      simple-scan

      yubioath-flutter
      kdiskmark
      songrec
      remmina

      # IRC Clients
      irssi
      weechat
      hexchat
      halloy

      element-desktop

      krita
      gimp3
      inkscape
      blender
      kdePackages.kdenlive

      audacity
      mpv
      vlc
      ncmpcpp
      yt-dlp
      ffmpeg

      # pipewire
      easyeffects
      helvum

      freecad
      kicad
      openscad

      mission-center

      # useful for iso files even without a cd drive
      brasero
      kdePackages.k3b

      ocf-okular
      ocf-papers

      # TEXT & CODE EDITORS
      vscode-fhs
      vscodium-fhs
      rstudio
      zed-editor
      jetbrains.idea-oss
      gnome-builder

      gitg
      meld

      # GAMES
      dwarf-fortress
      prismlauncher
      unciv
      superTuxKart
      tetris
      antimicrox

      # Editors
      emacs
      neovim
      helix
      kakoune

      # Languages
      (python3.withPackages (ps: [ ps.tkinter ps.numpy ps.pygobject3 ]))
      poetry
      ruby
      elixir
      clojure
      ghc
      rustup
      clang
      nodejs_22
      graphviz
      nix-du
      nix-output-monitor
      dix
      lldb
      gdb
      valgrind
      go
      sqlite
      zulu25
      godot

      # File management tools
      zip
      unzip
      _7zz
      eza
      lsd
      bat
      ranger
      fd
      rclone
      sshfs

      # Cosmetics
      neofetch
      pfetch-rs

      # devtools
      devenv
      claude-code

      fastfetch
      onefetch
      cpufetch
      gpufetch

      # Other tools
      bar
      fzf
      s-tui
      fio
      wiremix
      yubikey-manager
      gh
      cdrtools # useful for iso files even without a cd drive
      kana
      freerdp
    ];
  };
}
