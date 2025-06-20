{ lib, config, ... }:

let
  cfg = config.ocf.github-actions;
  template = import ./template.nix;
in
{

  imports = [ ./options.nix ];
  config = lib.mkIf cfg.enable {
    containers = lib.mergeAttrsList (builtins.map (runner: (template (with runner; {inherit enable owner repo workflow tokenPath packages instances;}))) cfg.runners);
  };
}
