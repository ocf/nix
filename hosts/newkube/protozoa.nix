{ ... }:

{
  imports = [ ../../hardware/lockdown.nix ];

  ocf.network = {
    enable = true;
    lastOctet = 11;
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
        "eno1np0"
        "eno2np1"
      ];
    };
  };

  services.ocfKubernetes.enable = true;
  services.ocfKubernetes.isLeader = false;

  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_500GB_S58SNS0N727782J";
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
