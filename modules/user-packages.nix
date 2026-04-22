{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.ocf.userPackages = {
    enable = lib.mkEnableOption "user-facing packages for login servers";
  };

  config = lib.mkIf config.ocf.userPackages.enable {
    environment.systemPackages = with pkgs; [
      # Networking
      mosh
      pssh

      # Version control
      mercurial
      subversion

      # Shell utilities
      unison
      keychain
      autojump
      inotify-tools
      asciinema
      colordiff
      ack
      silver-searcher
      shellcheck
      pandoc

      # Editors
      neovim

      # Debuggers & build tools
      gdb
      cgdb
      valgrind
      autoconf
      automake
      cmake
      gnumake
      libtool
      pkg-config
      bison
      flex
      nasm

      # Languages & runtimes
      go
      jdk
      maven
      scala_3
      ghc
      cabal-install
      julia
      chicken
      nodejs
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

      # PHP
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

      # TeX
      texlive.combined.scheme-medium

      # Terminal clients & chat
      irssi
      weechat
      mutt
      alpine
      elinks
      lynx
      epic5
      znc

      # Media & graphics
      ffmpeg
      graphicsmagick
      graphviz

      # Database clients
      sqlite
      postgresql
      mariadb
      qrencode
      wp-cli

      # Misc utilities
      fortune
      cowsay
      lolcat
      neofetch
      screenfetch
      bogofilter
      units
      cdrkit

      # Python
      (python312.withPackages (
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
        ]
      ))
    ];
  };
}
