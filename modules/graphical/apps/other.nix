# other apps for ocf desktops

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
  options.ocf.graphical.apps.other.enable = lib.mkOption {
    type = lib.types.bool;
    description = "Enable other apps";
    default = cfg.enable && cfg.extra;
  };

  config = lib.mkIf cfg.apps.other.enable {
    programs.zoom-us.enable = true;
    programs.obs-studio.enable = true;
    programs.obs-studio.enableVirtualCamera = true;

    programs.thunderbird.enable = true;
    # FIXME: cosmic files does not read the multiple mimeapps.list files
    # correctly, but it does correctly read the one in XDG_CONFIG_HOME. thus,
    # mimeapps.list is stored in skel until this is fixed.
    #xdg.mime.defaultApplications."x-scheme-handler/mailto" = "thunderbird.desktop";

    environment.systemPackages = with pkgs; [
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
      irssi
      weechat
      hexchat
      halloy

      element-desktop

      # pipewire
      easyeffects
      helvum

      mission-center

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
      yubikey-manager
      cdrtools # useful for iso files even without a cd drive
      kana
      freerdp
    ];
  };
}
