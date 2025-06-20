{ lib, runner, ... }:

lib.mkIf runner.enable
{
  "ci-${runner.owner}-${runner.repo}-${runner.workflow}" = {
    ephemeral = true;
    autoStart = true;
    privateUsers = "pick";
    bindMounts = {
      "github-token" = {
        hostPath = runner.tokenPath;
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
                  name = "ci-${runner.owner}-${runner.repo}-${runner.workflow}-${toString (i+1)}";
                in
                {
                  name = name;
                  value = {
                    enable = true;
                    ephemeral = true;
                    user = null;
                    group = null;
                    replace = true;
                    noDefaultLabels = true;
                    extraLabels = [ "ci-${runner.owner}-${runner.repo}-${runner.workflow}" ];
                    url = "https://github.com/${runner.owner}/${runner.repo}";
                    tokenFile = "/run/runner.token";
                    extraPackages = runner.extraPackages;
                  };
                }
              )
              runner.instances
          );
        system.stateVersion = "24.11";
      };
  };
}

