{ pkgs, lib, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  # Empty Host, will put something here soon
  networking.hostName = "zecora";

  ocf.network = {
    enable = true;
    lastOctet = 44;
  };

  ocf.motd = {
    enable = true;
    description = "Unifi console.";
  };

  services.unifi.enable = true;

  system.stateVersion = "24.11";
}
