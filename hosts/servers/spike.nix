{ pkgs, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "spike";

  ocf.network = {
    enable = true;
    lastOctet = 24;
  };

  containers = builtins.listToAttrs (
    builtins.genList
      (i:
        let
          name = "ci-ocf-nix-${toString (i+1)}";
        in
        {
          name = name;
          value =
            {
              ephemeral = true;
              autoStart = true;
              bindMounts = {
                "github-token" = {
                  hostPath = "/run/secrets/spike-nix-build.token";
                  mountPoint = "/run/runner.token";
                  isReadOnly = true;
                };
              };
              config =
                { pkgs, ... }:
                {
                  nix.settings.experimental-features = "nix-command flakes";
                  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
                  services.github-runners = {
                    "nix-build-ci-${toString (i+1)}" = {
                      enable = true;
                      ephemeral = true;
                      replace = true;
                      url = "https://github.com/ocf/nix";
                      tokenFile = "/run/runner.token";
                      extraPackages = with pkgs; [
                        nix
                        sudo
                      ];
                    };
                  };
                  system.stateVersion = "24.11";
                };
            };
        }
      ) 4
  );


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
