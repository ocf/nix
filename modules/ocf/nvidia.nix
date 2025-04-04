{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.nvidia;
in
{
  options.ocf.nvidia = {
    enable = lib.mkEnableOption "Enable NVIDIA Drivers and Config";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.modesetting.enable = true;
    hardware.nvidia.open = true;
  };
}
