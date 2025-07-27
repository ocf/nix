{ pkgs, config, ... }:

{
  imports = [ ../../hardware/virtualized.nix ../../disko/spike.nix ];

  networking.hostName = "spike";

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  ocf.network = {
    enable = true;
    lastOctet = 24;
  };

  age.secrets.nix-ci-token.rekeyFile = ../../secrets/master-keyed/nix-ci-token.age;

  ocf.github-actions = {
    enable = true;
    runners = [
      {
        enable = true;
        repo = "nix";
        workflow = "build";
        tokenPath = config.age.secrets.nix-ci-token.path;
        instances = 4;
        packages = [ pkgs.nix ];
      }
    ];
  };
  system.stateVersion = "24.11";
}
