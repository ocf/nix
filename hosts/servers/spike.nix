{ pkgs, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "spike";

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  ocf.network = {
    enable = true;
    lastOctet = 24;
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
        extraPackages = [ pkgs.nix ];
      }
    ];
  };
  system.stateVersion = "24.11";
}
