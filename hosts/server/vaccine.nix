{ lib, pkgs, ... }:

{
  imports = [ ../../hardware/pandemic.nix ];

  ocf.network = {
    enable = true;
    bond = {
      enable = true;
      interfaces = [
        "eno1"
        "eno2"
      ];
    };
    lastOctet = 14;
  };

  disko.devices = {
    disk = {
      main = {
        device = "/dev/vdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
              attributes = [ 0 ]; # partition attribute
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

  boot.loader = {
    grub = {
      enable = true;
      device = "/dev/disk/by-id/ata-SuperMicro_SSD_SMC0515D92517CE71175";
    };

    systemd-boot.enable = false;
  };

  #services.ceph.enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "26.05";
}
