{
  config,
  lib,
  ...
}:

{
  options.ocf.vm = {
    enable = lib.mkEnableOption "build-vm options";
  };
  config = lib.mkIf config.ocf.vm.enable {
    users = {
      groups.ocf = {
        gid = 1000;
      };
      users.test = {
        isNormalUser = true;
        password = "test";
        createHome = true;
        group = "ocf";
      };
    };
    virtualisation.vmVariant.virtualisation = {
      memorySize = 8192;
      cores = 6;
      qemu.options = [
        "-vga virtio"
        "-display gtk,gl=on"
      ];
    };
  };
}
