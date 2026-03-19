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
    environment.etc."libreoffice/registry/languagetool.xcu".source = ./libreoffice-languagetool.xcu;

    xdg.mime.addedAssociations = {
      "image/jpeg"    = "org.kde.gwenview.desktop";
      "image/png"     = "org.kde.gwenview.desktop";
      "image/gif"     = "org.kde.gwenview.desktop";
      "image/webp"    = "org.kde.gwenview.desktop";
      "image/bmp"     = "org.kde.gwenview.desktop";
      "image/tiff"    = "org.kde.gwenview.desktop";
      "image/svg+xml" = "org.kde.gwenview.desktop";
    };

    environment.systemPackages = with pkgs; [
      kdePackages.gwenview

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
    ];

    ocf.graphical.apps.browsers.handlePDFs = true;
    assertions = [{
      assertion = cfg.apps.browsers.enable;
      message = "browser is used as default PDF viewer";
    }];
  };
}
