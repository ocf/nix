{ lib, config, ... }:

let
  cfg = config.ocf.nvidia;
in
{
  options.ocf.nvidia = {
    enable = lib.mkEnableOption "Enable NVIDIA Drivers and Config";
    # See: https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # It's recommend to use the open kernel drivers for turing and above
    open = lib.mkOption {
      description = "Use open source NVIDIA Kernel Drivers";
      type = lib.types.bool;
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.modesetting.enable = true;
    hardware.nvidia.open = cfg.open;
  };
}
