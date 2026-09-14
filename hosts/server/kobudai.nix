{ lib, pkgs, ... }:

{
  ocf.network = {
    enable = true;
    bond = {
      enable = true;
      interfaces = [
        "eno1"
        "eno2"
      ];
    };
    lastOctet = 6;
  };

  # nfs server should not be mounting nfs from itself
  ocf.nfs.enable = lib.mkForce false;

  # in linux 6.6, nfsd added write delegations. however, this causes old clients to
  # get stuck spamming TEST_STATEID (~5000/s) causing open() to take multiple seconds:
  #
  # fixed client-side in linux 6.7, but death (and others) are super old (5.10 lol),
  # so let's disable delegations for now by disabling vfs leases.
  #
  # issue: https://gitlab.com/gitlab-org/gitlab-foss/-/work_items/52017
  # fix: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=a9b8d90f8726
  boot.kernel.sysctl."fs.leases-enable" = 0;

  services.nfs.server = {
    enable = true;
    # https://github.com/ocf/puppet/blob/a081b2210691bd46d585accc8548c985188486a0/modules/ocf_filehost/manifests/init.pp#L10-L16
    exports."/opt/homes" =
      lib.genAttrs
        [
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
        ]
        (_: [
          "rw"
          "fsid=0"
          "no_subtree_check"
          "no_root_squash"
        ])
      // {
        "*.ocf.berkeley.edu" = [
          "rw"
          "fsid=0"
          "no_subtree_check"
          "root_squash"
          "sec=krb5p"
        ];
      };
  };

  systemd.services.rquotad = {
    serviceConfig = {
      ExecStart = "${lib.getExe' pkgs.quota "rpc.rquotad"} --foreground --port 875";
    };
    wantedBy = [ "multi-user.target" ];
  };

  networking.firewall.allowedTCPPorts = [
    # sufficient for NFSv4
    2049

    # rquotad
    875

    # portmapper
    111
  ];

  networking.firewall.allowedUDPPorts = [
    # rquotad
    875

    # portmapper
    111
  ];

  # FIXME remove and make sure it still boots
  hardware.enableAllHardware = true;

  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/ata-SuperMicro_SSD_SMC0515D92517CF42434";
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

  boot.swraid = {
    enable = true;
    mdadmConf = ''
      MAILADDR root@ocf.berkeley.edu
      ARRAY /dev/md/nfs metadata=1.2 UUID=46b10914:9f84099b:dd54304a:917d7898
    '';
  };

  fileSystems = {
    "/opt/homes" = {
      device = "/dev/md/nfs";
      fsType = "ext4";
      options = [
        "noatime"
        "nodev"
        "usrquota"
      ];
    };

    # Bind mount /opt/homes/home to /home. This allows running (for NFSv3)
    #     mount kobudai:/home /home
    # In fact, since homes is CNAMEd to kobudai, even
    #     mount homes:/home /home
    # works and that's what the Puppet config in modules/ocf/manifests/nfs.pp does.
    # This also means that your home on the filehost when you login to it is
    # the shared NFS home.
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
