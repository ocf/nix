{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  ocf.network = {
    enable = true;
    lastOctet = 50;
  };

  ocf.auth.staffOnlySSH = false;

  ocf.webhost = {
    enable = true;
    websites = [
      {
        name = "docs";
        githubActionsPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGfbHPz52unvWwGAEVenVycOIQqIoZEj5OYi8vzJ1mJS";
      }
      {
        name = "decal";
        githubActionsPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBcmT7hG2lb4HigSYs7NoXfZx31vmBxheglR4ryv/LgK";
      }
    ];
    redirects."bestdocs".target = "docs";
  };

  system.stateVersion = "24.11";
}
