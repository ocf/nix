{ pkgs, lib, inputs, ... }:

# TODO: Move this to pkgs/ or come up with a better way to manage custom scripts
let
  vncScript = pkgs.writeShellScriptBin "ocf-tv" ''
    ${lib.getExe pkgs.openssh_gssapi} -M -S /tmp/ocftv-ssh-ctl -fNT -L 5900:localhost:5900 tornado
    ${lib.getExe pkgs.remmina} --no-tray-icon --disable-news --disable-stats --enable-extra-hardening -c vnc://localhost
    ${lib.getExe pkgs.openssh_gssapi} -S /tmp/ocftv-ssh-ctl -O exit tornado
  '';
  # override ocf-tv from util
  ocf-tv = pkgs.hiPrio vncScript;

in
{

  # Colmena tagging
  deployment.tags = [ "desktop" ];

  ocf = {
    etc.enable = true;
    graphical.enable = true;
    browsers.enable = true;
    tmpfsHome.enable = true;
    network.wakeOnLan.enable = true;
  };

  boot.loader.systemd-boot.consoleMode = "max";

  # Enable support SANE scanners
  hardware.sane.enable = true;

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
    ocf-tv

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
