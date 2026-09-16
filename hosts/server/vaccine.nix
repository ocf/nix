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
        device = "/dev/disk/by-id/ata-SuperMicro_SSD_SMC0515D92517CE71175";
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

  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "26.05";
}
