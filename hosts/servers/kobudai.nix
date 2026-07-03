{
  networking.hostName = "kobudai";

  ocf.network = {
    enable = true;
    lastOctet = 128;
  };

  ocf.nfs-export = {
    enable = true;
    # https://github.com/ocf/puppet/blob/a081b2210691bd46d585accc8548c985188486a0/modules/ocf_filehost/manifests/init.pp#L10-L16
    exports."/opt/homes" = [
      {
        hosts = [
          "admin"
          "www"
          "ssh"
          "apphost"
          "adenine"
          "guanine"
          "cytosine"
          "thymine"
          "tsunami"
          "supernova"
        ];
        options = [
          "rw"
          "fsid=0"
          "no_subtree_check"
          "no_root_squash"
        ];
      }
      {
        hosts = [ "*.ocf.berkeley.edu" ];
        options = [
          "rw"
          "fsid=0"
          "no_subtree_check"
          "root_squash"
          "sec=krb5p"
        ];
      }
    ];
  };

  boot.loader = {
    grub.enable = true;
    systemd-boot.enable = false;
  };

  # FIXME remove and make sure it still boots
  hardware.enableAllHardware = true;

  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/ata-Samsung_SSD_850_PRO_1TB_S252NXAGA05227F";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            MBR = {
              type = "EF02";
              size = "1M";
              priority = 1;
            };
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

  boot.swraid = {
    enable = true;
    mdadmConf = ''
      MAILADDR root@ocf.berkeley.edu
      ARRAY /dev/md/nfs metadata=1.2 UUID=46b10914:9f84099b:dd54304a:917d7898 name=dataloss:nfs
    '';
  };

  ocf.nfs.enable = false;

  fileSystems = {
    "/opt/homes" = {
      device = "/dev/md/nfs";
      fsType = "ext4";
      options = [
        "noacl"
        "noatime"
        "nodev"
        "usrquota"
      ];
    };

    # Bind mount /opt/homes/home to /home. This allows running
    #     mount kobudai:/home /home
    # In fact, since home is CNAMEd to filehost is CNAMEd to kobudai, even
    #     mount homes:/home /home
    # works and that's what the Puppet config in modules/ocf/manifests/nfs.pp does.
    "/home" = {
      device = "/opt/homes/home";
      fsType = "none";
      options = [ "bind" ];
    };
    "/services" = {
      device = "/opt/homes/services";
      fsType = "none";
      options = [ "bind" ];
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "25.11";
}
