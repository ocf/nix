{ lib, config, ... }:

let
  cfg = config.ocf.github-actions;
  template = import ./template.nix;
in
{

  imports = [ ./options.nix ];
  config = lib.mkIf cfg.enable {
    containers = lib.map template cfg.runners;
  };
}
