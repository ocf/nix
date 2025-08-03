{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "amethyst";

  ocf.network = {
    enable = true;
    lastOctet = 50;
  };

  ocf.webhost = {
    enable = true;
    websites = [
      {
        enable = true;
        name = "bestdocs";
        githubActionsPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGfbHPz52unvWwGAEVenVycOIQqIoZEj5OYi8vzJ1mJS";
      }
    ];
  };



  system.stateVersion = "24.11";
}
