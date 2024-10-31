{ pkgs, lib, inputs, ... }:

{

  # Colmena tagging
  deployment.tags = [ "desktop" ];

  ocf = {
    etc.enable = true;
    graphical.enable = true;
    tmpfsHome.enable = true;
    network.wakeOnLan.enable = true;
  };

  boot.loader.systemd-boot.consoleMode = "max";

  environment.systemPackages = with pkgs; [
    # Editors
    emacs
    neovim
    helix
    kakoune

    # Languages
    (python312.withPackages (ps: [ ps.ocflib ]))
    poetry
    ruby
    elixir
    clojure
    ghc
    rustup
    clang
    nodejs_22

    # File management tools
    zip
    unzip
    _7zz
    eza
    tree
    dua
    bat

    # Other tools
    ocf-utils
    bar
    tmux
    s-tui

    # Cosmetics
    neofetch
    pfetch-rs
  ];

  services = {
    avahi.enable = true;

    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
    };
  };

  security.rtkit.enable = true;
  hardware.pulseaudio.enable = false;

  # Needed for generic Linux programs
  # More info: https://nix.dev/guides/faq#how-to-run-non-nix-executables
  programs.nix-ld.enable = true;
}
