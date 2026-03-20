# documents and media

{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.graphical;
in
{
  options.ocf.graphical.apps.documents.enable = lib.mkOption {
    type = lib.types.bool;
    description = "Install software for working with documents and media on OCF lab desktops";
    default = cfg.enable;
  };


  config = lib.mkIf cfg.apps.documents.enable {
    # grammar checker for libreoffice
    services.languagetool.enable = true;
    services.languagetool.public = false;

    # Apache OpenOffice documentation mentions administrator config methods but
    # LibreOffice docs do not mention it, and it seems sparsely documented if
    # at all documented. I just inserted what LibreOffice does when you change
    # the settings into the skeleton home to keep things simple (and formatted
    # the xml nicely).
    # FIXME: doesnt work, "Permission denied", probably has something to do
    # with environment.etc."skel" already being set to a directory, so i put
    # the config in ../skel instead. this does mean that languagetool will be
    # enabled in libreoffice regardless of whether the system has it.
    #environment.etc."skel/.config/libreoffice/4/user/registrymodifications.xcu".source = ./libreoffice-config.xcu;

    xdg.mime.defaultApplications = {
      "image/jpeg"    = "org.kde.gwenview.desktop";
      "image/png"     = "org.kde.gwenview.desktop";
      "image/gif"     = "org.kde.gwenview.desktop";
      "image/webp"    = "org.kde.gwenview.desktop";
      "image/bmp"     = "org.kde.gwenview.desktop";
      "image/tiff"    = "org.kde.gwenview.desktop";
      "image/svg+xml" = "org.kde.gwenview.desktop";
    };

    environment.systemPackages = with pkgs; [
      # scanning
      simple-scan

      # pdfs
      ocf-okular
      ocf-papers

      # libreoffice
      libreoffice-still
      mythes
      hunspell # spell check
      hunspellDicts.en_US
      hyphenDicts.en_US

      # editors
      xournalpp

      kdePackages.gwenview
      vlc

      # useful for iso files even without a cd drive
      # needed for melange (cd drive host)
      brasero
      kdePackages.k3b
    ] ++ lib.optionals cfg.extra [
      apostrophe
      #texliveFull
      texstudio
      pandoc
      img2pdf

      krita
      gimp3
      darktable
      inkscape
      blender
      drawio
      octave
      kdePackages.kdenlive
      davinci-resolve

      audacity
      ardour
      musescore
      milkytracker
      schismtracker

      freecad
      kicad
      openscad

      mpv
      ncmpcpp
      strawberry
      xmp
      yt-dlp
      ffmpeg
      songrec

      exiftool
      imagemagick
    ];

    ocf.graphical.apps.browsers.handlePDFs = true;
    assertions = [{
      assertion = cfg.apps.browsers.enable;
      message = "browser is used as default PDF viewer";
    }];
  };
}
