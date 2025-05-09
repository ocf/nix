{ pkgs, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "spike";

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  ocf.network = {
    enable = true;
    lastOctet = 24;
  };

  containers =
    let
      owner = "ocf";
      repo = "nix";
      workflow = "build";
      githubTokenPath = "/run/secrets/spike-nix-build.token";
      instances = 4;
      extraPackages = [ pkgs.nix ];
    in
    builtins.listToAttrs (
      builtins.genList
        (i:
          let
            name = "ci-${owner}-${repo}-${workflow}-${toString (i+1)}";
          in
          {
            name = name;
            value =
              {
                ephemeral = true;
                autoStart = true;
                privateUsers = "pick";
                bindMounts = {
                  "github-token" = {
                    hostPath = githubTokenPath;
                    mountPoint = "/run/runner.token";
                    isReadOnly = true;
                  };
                  "host-notify" = {
                    hostPath = "/run/container-finished";
                    mountPoint = "/mnt/host-notify";
                    isReadOnly = false;
                  };
                };
                config =
                  { pkgs, lib, ... }:
                  {
                    nix.settings.experimental-features = "nix-command flakes";
                    networking.firewall.enable = true;
                    services.github-runners = {
                      "${name}" = {
                        enable = true;
                        ephemeral = true;
                        replace = true;
                        url = "https://github.com/${owner}/${repo}";
                        tokenFile = "/run/runner.token";
                        extraPackages = extraPackages;
                        serviceOverrides = {
                          BindPaths = [ "/mnt/host-notify" ];
                        };
                      };
                    };
                    systemd.services = {
                      "github-runner-${name}" = {
                        serviceConfig = { ExecStop = "${lib.getExe' pkgs.coreutils "touch"} /mnt/host-notify/${name}"; };
                      };
                    };
                    system.stateVersion = "24.11";
                  };
              };
          }
        )
        instances
    );


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
