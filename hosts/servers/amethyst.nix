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
      {
        enable = true;
        name = "decal";
        githubActionsPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBcmT7hG2lb4HigSYs7NoXfZx31vmBxheglR4ryv/LgK";
      }
    ];
  };



  system.stateVersion = "24.11";
}
