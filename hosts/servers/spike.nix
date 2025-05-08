{ ... }:

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
      githubTokenPath = "/run/secrets/spike-nix-build.token";
      instances = 4;
    in
    builtins.listToAttrs (
      builtins.genList
        (i:
          let
            name = "ci-${owner}-${repo}-${toString (i+1)}";
          in
          {
            name = name;
            value =
              {
                ephemeral = true;
                autoStart = true;
                privateNetwork = true;
                bindMounts = {
                  "github-token" = {
                    hostPath = githubTokenPath;
                    mountPoint = "/run/runner.token";
                    isReadOnly = true;
                  };
                };
                # See: https://man.archlinux.org/man/systemd-nspawn.1#User_Namespacing_Options
                extraFlags = [
                  "--private-users=pick"
                  "--private-users-ownership=auto"
                ];
                config =
                  { pkgs, ... }:
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
                        extraPackages = [ pkgs.nix ];
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
