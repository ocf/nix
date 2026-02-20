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

    # userspace nvidia drivers to restore video memory
    hardware.nvidia.powerManagement.enable = true;
    boot.extraModprobeConfig = ''
      # needed to properly restore video memory after leaving suspend
      options nvidia NVreg_PreserveVideoMemoryAllocations=1

      # nvidia upstream defaults to /tmp, but recommends not storing on tmpfs.
      # our desktops have 32 gb of memory so this should be fine, and i would
      # prefer if we avoided storing video memory on unencrypted filesystems.
      # this is further improved if zram or encrypted swap is used.
      options nvidia NVreg_TemporaryFilePath=/tmp
    '';
  };
}
