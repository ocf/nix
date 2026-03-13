{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.graphical;
in
{
  options.ocf.graphical.apps.documents = lib.mkOption {
    type = lib.types.bool;
    description = "Install software for working with documents on OCF lab desktops";
    default = cfg.enable;
  };

  config = lib.mkIf cfg.apps.documents {
    # grammar checker for libreoffice
    services.languagetool.enable = true;
    services.languagetool.public = false;
    environment.etc."libreoffice/registry/languagetool.xcu".source = ./libreoffice-languagetool.xcu;

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
    ];
  };
}
