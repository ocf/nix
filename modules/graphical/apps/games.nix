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
  options.ocf.graphical.apps.games.enable = lib.mkOption {
    type = lib.types.bool;
    description = "Enable gaming configuration";
    default = cfg.enable && cfg.extra;
  };

  config = lib.mkIf cfg.apps.games.enable {
    hardware.graphics.enable32Bit = true;

    programs.steam.enable = true;
    programs.steam.protontricks.enable = true;

    environment.systemPackages = with pkgs; [
      # controller support
      antimicrox

      # GAMES
      dwarf-fortress
      unciv
      superTuxKart
      tetris

      # emulators
      dosbox
      dolphin-emu
      ryubing

      # minecraft
      prismlauncher
      worldpainter
      amidst
      mcaselector

      # windows compat
      lutris
      bottles
      winetricks
      wineWow64Packages.stable
    ];
  };
}
