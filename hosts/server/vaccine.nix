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

  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = "26.05";
}
