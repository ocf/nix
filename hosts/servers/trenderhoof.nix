{ ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "trenderhoof";

  ocf.network = {
    enable = true;
    lastOctet = 128;
  };

  ocf.nfs = {
    enable = true;
    # https://github.com/ocf/puppet/blob/a081b2210691bd46d585accc8548c985188486a0/modules/ocf_filehost/manifests/init.pp#L10-L16
    exports = [
      {
        directory = "/opt/homes";
        hosts = [
          "admin"
          "www"
          "ssh"
          "apphost"
          "adenine"
          "guanine"
          "cytosine"
          "thymine"
          "fluttershy"
          "rainbowdash"
        ];
        options = [
          "rw"
          "fsid=0"
          "no_subtree_check"
          "no_root_squash"
        ];
      }
    ];
  };

  fileSystems = {
    # Bind mount /opt/homes/home to /home. This allows running
    #     mount trenderhoof:/home /home
    # In fact, since home is CNAMEd to filehost is CNAMEd to trenderhoof, even
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

  system.stateVersion = "25.11";
}
