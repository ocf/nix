{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "spike";

  # allows spike to build for raspberry pi
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
        instances = 4;
      }
      {
        enable = true;
        repo = "mkdocs";
        workflow = "build";
      }
    ];
  };
  system.stateVersion = "24.11";
}
