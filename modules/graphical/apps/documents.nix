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
    environment.systemPackages = with pkgs; [
      # scanning
      simple-scan

      # pdfs
      ocf-okular
      ocf-papers

      # libreoffice
      libreoffice

      # editors
      xournalpp
    ];
  };
}
