{ ... }:

{
  imports = [ ../../hardware/riptide.nix ];

  ocf.network = {
    enable = true;
    lastOctet = 16;
    extraRoutes = [
      # We use these subnets for Kubernetes, they aren't part of the main /64
      {
        Destination = "2607:f140:8801:1::/64";
        Scope = "link";
      }
      {
        Destination = "2607:f140:8801:2::/64";
        Scope = "link";
      }
    ];

    bond = {
      enable = true;
      interfaces = [
        "ens1f0np0"
        "ens1f1np1"
      ];
    };
  };

  ocf.kubernetes.cluster = {
    enable = true;
    controlPlane = false;
    staging = false;
  };

  disko.devices = {
    disk = {
      main = {
        # superDOM
        device = "/dev/disk/by-id/ata-SuperMicro_SSD_SMC0515D92517CEE4099";
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?
}
