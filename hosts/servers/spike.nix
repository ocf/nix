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
    {
      "ci-${owner}-${repo}-${workflow}" = {
        ephemeral = true;
        autoStart = true;
        privateUsers = "pick";
        bindMounts = {
          "github-token" = {
            hostPath = githubTokenPath;
            mountPoint = "/run/runner.token";
            isReadOnly = true;
          };
        };
        config =
          { ... }:
          {
            nix.settings.experimental-features = "nix-command flakes";
            networking.firewall.enable = true;
            services.github-runners =
              builtins.listToAttrs (
                builtins.genList
                  (
                    i:
                    let
                      name = "ci-${owner}-${repo}-${workflow}-${toString (i+1)}";
                    in
                    {
                      name = name;
                      value = {
                        enable = true;
                        ephemeral = true;
                        replace = true;
                        noDefaultLabels = true;
                        extraLabels = [ "ci-${owner}-${repo}-${workflow}" ];
                        url = "https://github.com/${owner}/${repo}";
                        tokenFile = "/run/runner.token";
                        extraPackages = extraPackages;
                      };
                    }
                  )
                  instances
              );
            system.stateVersion = "24.11";
          };
      };
    };

  system.stateVersion = "24.11";
}
