{
  imports = [ ../../hardware/virtualized.nix ];

  ocf.network = {
    enable = true;
    lastOctet = 184;
  };

  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };

  ocf.nameserver.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "26.05";
}
