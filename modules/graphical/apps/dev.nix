# development related apps for ocf desktops

{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.graphical;
in
{
  options.ocf.graphical.apps.dev.enable = lib.mkOption {
    type = lib.types.bool;
    description = "Enable development related apps";
    default = cfg.enable && cfg.extra;
  };

  config = lib.mkIf cfg.apps.dev.enable {
    programs.java.enable = true; # set $JAVA_HOME
    programs.java.package = pkgs.zulu25;

    environment.systemPackages = with pkgs; [
      # gui editors
      emacs
      vscode-fhs
      vscodium-fhs
      rstudio
      zed-editor
      gnome-builder
      jetbrains.idea-oss
      jetbrains.pycharm-oss
      jetbrains.datagrip

      # tui editors
      neovim
      helix
      kakoune

      insomnia

      # git
      gitg
      github-desktop
      gh

      meld

      # devtools
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
      godot
      kotlin
      libxml2 # xmllint
    ];
  };
}
