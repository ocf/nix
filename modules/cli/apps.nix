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
      # tui editors
      neovim
      helix
      kakoune
      emacs # has both tui and gui

      # file management tools
      zip
      unzip
      _7zz
      eza
      lsd
      bat
      ranger
      fd
      rclone

      # terminal clients & chat
      irssi
      weechat
      mutt
      alpine
      elinks
      lynx
      epic5
      znc

      # fetch
      neofetch
      screenfetch
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

      # benchmarking
      s-tui
      fio

      # version control
      gh
      git
      mercurial
      pre-commit
      sapling
      subversion

      # debuggers, and build tools
      poetry
      ghc
      rustup # to install other versions not installed by default
      rustfmt
      rustc
      cargo
      clang
      dix
      lldb
      gdb
      valgrind
      sqlite
      kotlin
      cgdb
      autoconf
      automake
      cmake
      gnumake
      libtool
      pkg-config
      bison
      flex
      nasm

      nix-du
      nix-output-monitor
      devenv
      claude-code

      # languages & runtimes
      graphviz
      nodejs
      go
      godot # has both cli and gui tools
      libxml2 # xmllint
      elixir
      clojure
      maven
      scala_3
      cabal-install
      julia
      chicken
      octave
      (ruby.withPackages (
        ps: with ps; [
          mysql2
          sqlite3
          ronn
          rails
        ]
      ))
      (rWrapper.override {
        packages = with rPackages; [
          data_table
          dplyr
          ggplot2
          jsonlite
          lubridate
          magrittr
          markdown
          tidyr
          xml2
          zoo
        ];
      })

      # php
      (php.withExtensions (
        { enabled, all }:
        enabled
        ++ (with all; [
          bcmath
          bz2
          curl
          gd
          intl
          pdo_mysql
          pdo_sqlite
          soap
          zip
        ])
      ))

      # teX
      texlive.combined.scheme-medium

      # python
      (python3.withPackages (
        ps: with ps; [
          ipython
          notebook
          pandas
          flask
          jinja2
          lxml
          requests-oauthlib
          sympy
          tox
          twine
          pytest
          pytest-cov
          mysqlclient
          progressbar
          flake8
          mock
          tkinter
          slixmpp
          virtualenv
          numpy
          pygobject3
        ]
      ))

      # database clients
      sqlite
      postgresql
      mariadb
      qrencode
      wp-cli

      # media
      graphicsmagick
      ncmpcpp
      xmp
      yt-dlp
      ffmpeg
      exiftool
      imagemagick
      pandoc
      img2pdf

      # networking
      pssh

      # shell utilities
      unison
      keychain
      autojump
      inotify-tools
      asciinema
      colordiff
      ack
      silver-searcher
      shellcheck
      fzf
      bar
      ghostscript
      enscript

      # misc
      wiremix
      bogofilter
      units
      cdrtools # useful for iso files even without a cd drive

      # only really runs on the desktops since you need to plug the yubikey in
      yubikey-manager
    ];
  };
}
