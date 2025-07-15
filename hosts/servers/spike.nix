{ pkgs, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "spike";

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  ocf.network = {
    enable = true;
    lastOctet = 24;
  };

  ocf.secrets = {
    enable = true;
    hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKdD3u9lBJbWbNeQEHX+WvqgQLSAGrh9CF6dQdxfu6uE";
  };

  ocf.github-actions = {
    enable = true;
    runners = [
      {
        enable = true;
        repo = "nix";
        workflow = "build";
        tokenPath = "/run/secrets/spike-nix-build.token";
        instances = 4;
        packages = [ pkgs.nix ];
      }
    ];
  };
  system.stateVersion = "24.11";
}
