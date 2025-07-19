{ ... }:

{
  imports = [ ../../hardware/devkube.nix ];

  networking.hostName = "stringofpearls";

  ocf.network = {
    enable = true;
    lastOctet = 102;
    extraRoutes = [
      # We use these subnets for Kubernetes, they aren't part of the main /64
      { Destination = "2607:f140:8801:1::/64"; Scope = "link"; }
      { Destination = "2607:f140:8801:2::/64"; Scope = "link"; }
    ];
  };

  services.ocfDevKubernetes.enable = true;
  services.ocfDevKubernetes.isLeader = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
