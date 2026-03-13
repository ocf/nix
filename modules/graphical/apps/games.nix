{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.graphical;
in
{
  options.ocf.graphical.apps.games = lib.mkOption {
    type = lib.types.bool;
    description = "Enable gaming configuration";
    default = cfg.enable && cfg.extra;
  };

  config = lib.mkIf cfg.apps.games {
    programs.steam.enable = true;

    environment.systemPackages = with pkgs; [
      # GAMES
      dwarf-fortress
      prismlauncher
      unciv
      superTuxKart
      tetris
      antimicrox
  };
}
