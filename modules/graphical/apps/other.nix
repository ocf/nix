# other apps for ocf desktops

{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.graphical;
in
{
  options.ocf.graphical.apps.other.enable = lib.mkOption {
    type = lib.types.bool;
    description = "Enable other apps";
    default = cfg.enable && cfg.extra;
  };

  config = lib.mkIf cfg.apps.other.enable {
    programs.zoom-us.enable = true;
    programs.obs-studio.enable = true;
    programs.obs-studio.enableVirtualCamera = true;
    programs.java.enable = true; # set $JAVA_HOME
    programs.java.package = pkgs.zulu25;

    programs.thunderbird.enable = true;
    xdg.mime.addedAssociations."x-scheme-handler/mailto" = "thunderbird.desktop";

    environment.systemPackages = with pkgs; [
      # extra terminal emulators
      alacritty
      st
      ghostty

      yubioath-flutter
      kdiskmark
      remmina

      # IRC Clients
      irssi
      weechat
      hexchat
      halloy

      element-desktop

      # pipewire
      easyeffects
      helvum

      mission-center

      # TEXT & CODE EDITORS
      vscode-fhs
      vscodium-fhs
      rstudio
      zed-editor
      jetbrains.idea-oss
      gnome-builder

      gitg
      meld

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
