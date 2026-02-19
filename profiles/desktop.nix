{ pkgs, lib, inputs, ... }:

# TODO: Move this to pkgs/ or come up with a better way to manage custom scripts
let
  vncScript = pkgs.writeShellScriptBin "ocf-tv" ''
    ${lib.getExe pkgs.openssh_gssapi} -M -S /tmp/ocftv-ssh-ctl -fNT -L 5900:localhost:5900 tornado
    ${lib.getExe pkgs.remmina} --no-tray-icon --disable-news --disable-stats --enable-extra-hardening -c vnc://localhost
    ${lib.getExe pkgs.openssh_gssapi} -S /tmp/ocftv-ssh-ctl -O exit tornado
  '';
  # override ocf-tv from util
  ocf-tv = lib.hiPrio vncScript;
in
{

  # Colmena tagging
  deployment.tags = [ "desktop" ];

  ocf = {
    # TODO: need ensure host keys can't be stolen by booting an external drive...
    acme.enable = false;

    etc.enable = true;
    graphical.enable = true;
    browsers.enable = true;
    tmpfsHome.enable = true;
    network.wakeOnLan.enable = true;
    logged-in-users-exporter.enable = true;
  };

  boot.loader.systemd-boot.consoleMode = "max";

  # Enable support SANE scanners
  hardware.sane.enable = true;

  zramSwap.enable = true;

  documentation.dev.enable = true;

  environment.systemPackages = with pkgs; [
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

    # File management tools
    zip
    unzip
    _7zz
    eza
    lsd
    tree
    bat
    ranger
    lf
    fd
    sshfs
    dua
    rclone

    # Other tools
    bar
    fzf
    tmux
    s-tui
    fio
    ocf-tv
    remmina
    simple-scan
    cdrtools # useful for iso files even without a cd drive
    wiremix
    yubikey-manager
    gh
    ffmpeg
    element-desktop
    ncmpcpp
    yt-dlp
    kana
    freerdp

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

    # COSMIC Applets
    ocf-cosmic-applets

    # IRC password prompt
    kdePackages.kdialog

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
  services.pulseaudio.enable = false;

  # needed for accessing totp codes on yubikey via yubico authenticator
  services.pcscd.enable = true;

  # enable secure attention key (also enables unraw/xlate)
  boot.kernel.sysctl."kernel.sysrq" = 4;

  # Needed for generic Linux programs
  # More info: https://nix.dev/guides/faq#how-to-run-non-nix-executables
  programs.nix-ld.enable = true;
}
