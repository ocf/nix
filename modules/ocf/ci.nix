{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.ci;
in
{
  options.ocf.ci = {
    enable = lib.mkEnableOption "Enable OCF Github Actions CI/CD";
  };

  config = lib.mkIf cfg.enable { };
}
