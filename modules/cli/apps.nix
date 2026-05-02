{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.cli.apps;
in
{
  options.ocf.cli.apps.enable = lib.mkEnableOption "Install CLI apps";

  config = lib.mkIf cfg.enable {
    programs.java.enable = true; # set $JAVA_HOME
    programs.java.package = pkgs.zulu25;

    environment.systemPackages = with pkgs; [
      # tui irc
      irssi
      weechat

      # Cosmetics
      neofetch
      pfetch-rs
      fastfetch
      onefetch
      cpufetch
      gpufetch

      pokemonsay
      ponysay
      cowsay
      kittysay
      fortune
      lolcat
      pokemon-colorscripts

      # Other tools
      bar
      fzf
      s-tui
      fio
      wiremix
      cdrtools # useful for iso files even without a cd drive

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

      # tui editors
      neovim
      helix
      kakoune
      emacs # has both tui and gui

      gh
      git
      mercurial
      sapling
      subversion

      devenv
      claude-code

      # Languages
      (python3.withPackages (ps: [
        ps.tkinter
        ps.numpy
        ps.pygobject3
      ]))
      poetry
      ruby
      elixir
      clojure
      ghc
      rustup # to install other versions not installed by default
      rustfmt
      rustc
      cargo
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
      godot # has both cli and gui tools
      kotlin
      libxml2 # xmllint

      ncmpcpp
      xmp
      yt-dlp
      ffmpeg
      exiftool
      imagemagick
      pandoc
      img2pdf

      # only really runs on the desktops since you need to plug the yubikey in
      yubikey-manager
    ];
  };
}
