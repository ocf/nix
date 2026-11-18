# Hardware configuration for 2024 PC upgrade with:
# - ASRock A620I Lightning Wifi
# - Ryzen 5 8600G
# Requires specifying `disko.devices.disk.main.device` in the host's config.

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  disko.devices = {
    disk.main = {
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
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zroot";
            };
          };
        };
      };
    };
    zpool.zroot = {
      type = "zpool";
      options = {
        ashift = "12";
      };
      rootFsOptions = {
        mountpoint = "none";
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        normalization = "none";
        atime = "off";
      };
      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          postCreateHook = ''
            zfs list -t snapshot -H -o name | grep -E '^zroot/root@blank$' || zfs snapshot zroot/root@blank
          '';
        };
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
        };
        persist = {
          type = "zfs_fs";
          mountpoint = "/persist";
        };
      };
    };
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp9s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp8s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
